# AI credit per-user attribution

This document explains why per-user AI credit panels in the Grafana dashboard
may show zeros for enterprise-owned organizations, and what is required to
populate them.

## The constraint

GitHub's `/organizations/{org}/settings/billing/ai_credit/usage` endpoint
accepts a `?user=USERNAME` query parameter, but returns HTTP `403` when called
against an *enterprise-owned* organization:

> Organization admins for enterprise owned organizations cannot filter usage
> by user.

The `/users/{username}/settings/billing/ai_credit/usage` endpoint also returns
`404` for org-managed Copilot licenses because the user does not own a
personal Copilot subscription.

As a result, when the ingestion runs against an enterprise-owned org with an
*org admin* PAT, GitHub will not return per-user attribution at all. The only
data available is the org-aggregate totals (per day, per model, per SKU, per
product).

## What the ingestion does today

- **Enterprise scope** (`SCOPE_TYPE=enterprise` + an enterprise slug):
  the ingestion calls the async usage-report export endpoint
  (`POST /enterprises/{ent}/settings/billing/reports`), polls until the
  report is `completed`, downloads each CSV in `download_urls`, and writes
  per-user-per-day rows. This requires a PAT with `manage_billing:enterprise`.
- **Organization scope** (default): the ingestion calls the org AI credit
  endpoint *without* the `?user=` filter and stores org-aggregate line items.
  `user_login` is empty on every record, so the
  `copilot_ai_credit_user_daily` index is populated with zero-credit
  placeholders (one per seat assignee per day). Org-aggregate panels driven
  by `copilot_ai_credit_usage` are accurate.

## Required to enable per-user attribution

You need both a **role** on the enterprise account and a **PAT scope**.

### 1. GitHub role (on the enterprise account)

The user who owns the PAT must be one of:

- **Enterprise owner**, or
- **Enterprise billing manager**

Organization-level admin / billing-manager is not sufficient — GitHub will
return `403` for the enterprise billing endpoints.

### 2. PAT scopes

Use a **classic PAT**. Fine-grained PATs do not currently cover enterprise
billing endpoints. Create at <https://github.com/settings/tokens> →
**Generate new token (classic)** and select:

| Scope | Why it is needed |
| --- | --- |
| `manage_billing:enterprise` | Required for `/enterprises/.../settings/billing/reports` endpoints. |
| `read:enterprise` | Required for the enterprise seat / metrics calls already used by `cpuad-updater`. |
| `read:org` | Required for org-level seat assignments and metrics. |
| `repo` (or `public_repo`) | Only needed if you also want repository-level data. |

If the enterprise enforces SAML SSO, click **Configure SSO** next to the new
token and authorize it for each organization in the enterprise before using
it. Without SSO authorization, the API will return `403` for SSO-protected
resources.

### 3. Pre-flight test (recommended before changing ingestion config)

Validate the new PAT against the enterprise endpoint *before* touching
`.env`:

```pwsh
$pat = "<new-pat>"
$ent = "<enterprise-slug>"
$h = @{
  "Accept"        = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2026-03-10"
  "Authorization" = "Bearer $pat"
}
Invoke-RestMethod -Method Get -Headers $h `
  -Uri "https://api.github.com/enterprises/$ent/settings/billing/reports"
```

Expected outcomes:

- `200` with a `usage_report_exports` array (possibly empty) → cleared to
  proceed.
- `403` → role missing, or PAT not SSO-authorized for the enterprise.
- `404` → wrong enterprise slug, or enterprise billing platform not enabled.

### 4. Switch the ingestion to enterprise scope

Update `.env` (or container environment):

```env
SCOPE_TYPE=enterprise
ENTERPRISE_SLUGS=<your-enterprise-slug>
GITHUB_PAT=<your-enterprise-admin-pat>
```

Find the enterprise slug in the URL of your enterprise page:
`https://github.com/enterprises/<your-enterprise-slug>`.

If `ORGANIZATION_SLUGS` is also set, comment it out (or leave both — the
ingestion will process both scopes, but per-user AI credit attribution only
comes from the enterprise scope).

### 5. Wipe existing AI credit indices and restart

```pwsh
Invoke-RestMethod -Method Delete `
  -Uri "http://localhost:9200/copilot_ai_credit_usage"
Invoke-RestMethod -Method Delete `
  -Uri "http://localhost:9200/copilot_ai_credit_user_daily"
docker compose restart cpuad-updater
docker logs cpuad-updater -f
```

### 6. What to watch for in the logs

In order, you should see:

1. `Requesting AI credit report export for enterprise <slug>` — POST job
   accepted.
2. `AI credit report <uuid> status=processing, sleeping 10s...` — polling
   loop. The first run may take 1–10 minutes for large date ranges.
3. `AI credit report <uuid> completed with N download URL(s)` — CSV(s)
   ready.
4. `Parsed <rows> AI credit rows from download N` — rows ingested with
   per-user attribution.

If the report export fails for any reason (403, timeout, network), the
ingestion automatically falls back to the org-aggregate path and logs a
warning, so you will still get gross totals — just without user breakdown.

## Environment variables (report export)

| Variable | Default | Description |
| --- | --- | --- |
| `AI_CREDIT_REPORT_TIMEOUT` | `600` | Max seconds to wait for the report job to complete. |
| `AI_CREDIT_REPORT_POLL_INTERVAL` | `10` | Seconds between polls of the report status. |
