# Opus 4.7 Implementation Plan: PRU → UBB AI Credits

## Objective
Move dashboard focus from PRU-style usage framing to **per-user AI credits consumption** under UBB, without exposing monetary cost fields.

## Current-State Findings
- Current ETL (`/src/cpuad-updater/main.py`) ingests seat billing, team usage, and user behavior metrics.
- User-level behavior is available in `copilot_user_metrics` but AI-credit usage is not currently ingested.
- Grafana dashboard (`/src/cpuad-updater/grafana/dashboard-template.json`) has strong per-user analytics panels that can be extended with credit consumption.

## Workstream 1 — Billing Data Ingestion
1. Add AI usage report extraction path for org/enterprise scopes.
2. Parse report lines into normalized records with:
   - `day`, `organization_slug`, `slug_type`, `user_login`, `assignee_team_slug`
   - `sku`, `product`, `model`, `unit_type`
   - raw quantity + normalized credit quantity
3. Preserve raw unit fields for auditability while using normalized credit fields for dashboards.
4. Add dedupe key strategy with deterministic `unique_hash` for idempotent re-runs.

## Workstream 2 — ETL Integration
1. Extend `Indexes` in `/src/cpuad-updater/main.py` with AI-credit indexes.
2. Add post-user-metrics processing block in `main()` to:
   - fetch credit usage
   - enrich with seat assignment team mapping
   - write line-item and aggregated credit docs
3. Add backfill and overlap controls via env vars to capture delayed billing finalization.
4. Implement graceful degradation when billing scope/API is unavailable.

## Workstream 3 — Elasticsearch Schema
Create mappings under `/src/cpuad-updater/mapping/`:
- `copilot_ai_credit_usage_mapping.json` (line-item grain)
- `copilot_ai_credit_user_daily_mapping.json` (daily per-user rollup)
- `copilot_ai_credit_user_summary_mapping.json` (window summaries/rankings)
- optional budget mapping if allowance tracking is needed.

## Workstream 4 — Aggregation Model
Build per-user derived metrics:
- total credits (range)
- active credit days
- credits per active day
- top model/product/SKU by credits
- share of org credits
- trend metrics (7/28/90 day)

Join behavior context from `copilot_user_metrics` to explain **how** credits are consumed:
- `used_chat`, `used_agent`
- interaction/completion/acceptance counts
- top feature/model attributes

## Workstream 5 — Grafana Changes
1. Add data sources in `/src/cpuad-updater/grafana/update_grafana.py` for AI-credit indexes.
2. Add new dashboard row in `/src/cpuad-updater/grafana/dashboard-template.json`:
   - Total AI credits
   - Credits per active user
   - Daily credits trend
   - Credits by model/product/SKU
   - Top users by credits
   - Per-user detailed credit breakdown table
   - User-by-day credit drilldown
3. Keep monetary fields hidden; only credits shown.
4. Keep existing behavioral panels but relabel as contextual/legacy where needed.

## Workstream 6 — Backward Compatibility
- Additive rollout only; do not remove existing indexes/panels initially.
- Gate with `ENABLE_AI_CREDITS` style feature flag.
- Provide empty-state guidance if credit data is unavailable.

## Workstream 7 — Validation
1. Mapping JSON validity + index creation checks.
2. ETL correctness checks:
   - idempotency after repeat runs
   - aggregate reconciliation between line-item and rollup indexes
3. Dashboard validation for filters and panel correctness by org/team/user.
4. Explicit check that no currency fields/labels are displayed.

## Workstream 8 — Rollout Plan
1. Ship schema + ETL behind feature flag.
2. Run in dev with short backfill and reconciliation.
3. Add dashboard row collapsed by default.
4. Promote to production and switch default views after validation.

## Risks & Mitigations
- Missing user dimension in billing export → fallback to per-user filtered fetch strategy.
- Rate limit pressure → windowed fetch, retries, overlap-based incremental sync.
- Late-arriving records → configurable overlap + deterministic upsert.
- Identity mismatch with user metrics joins → define fallback handling and quality checks.

## Open Questions
1. Should billing source of truth be org-level, enterprise-level, or both?
2. Should zero-credit assigned users appear in user tables?
3. Should cost-center segmentation be first-class in this dashboard?
4. Which historical lookback is required for initial backfill?
