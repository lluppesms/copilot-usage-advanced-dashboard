# Testing Guide — Copilot Usage Advanced Dashboard

This guide explains how to test the dashboard end-to-end, starting with a fast local Docker run and — optionally — progressing to a full Azure deployment.

**You do not need Azure to test.** The entire stack runs locally with Docker Compose.

---

## Table of Contents

- [Phase 1 — Validate Prerequisites](#phase-1--validate-prerequisites)
- [Phase 2 — Run Locally with Docker Compose](#phase-2--run-locally-with-docker-compose)
- [Phase 3 — Validate Core Behavior Locally](#phase-3--validate-core-behavior-locally)
- [Phase 4 — Deploy to Azure (optional)](#phase-4--deploy-to-azure-optional)
- [Phase 5 — Validate Azure Deployment](#phase-5--validate-azure-deployment)
- [Quick-Reference Validation Commands](#quick-reference-validation-commands)

---

## Phase 1 — Validate Prerequisites

Run the included validation script to check Docker, your `.env` file, and required environment variables before attempting to start the stack.

### Linux / macOS

```bash
bash scripts/validate-local-setup.sh
```

### Windows (PowerShell)

```powershell
.\scripts\Validate-LocalSetup.ps1
```

The script checks:

| Check | What it verifies |
|---|---|
| Docker installed and running | `docker info` succeeds |
| Docker Compose available | `docker compose version` succeeds |
| `.env` file exists | Copy from `.env.template` if missing |
| `GITHUB_PAT` is set and not a placeholder | Token with `manage_billing:copilot` scope |
| `ORGANIZATION_SLUGS` or `ENTERPRISE_SLUGS` is set | At least one org/enterprise target |
| Ports 8080 and 9200 are free | No conflicting services |

If the script exits with errors, fix each one before continuing.

### Create `.env` from the template

```bash
cp .env.template .env
# Edit .env — at minimum set:
#   GITHUB_PAT=ghp_your_token_here
#   ORGANIZATION_SLUGS=your-org-name
```

> **Token scopes required:** `manage_billing:copilot`, `read:enterprise`, `read:org`  
> Create a token at: <https://github.com/settings/tokens>

---

## Phase 2 — Run Locally with Docker Compose

```bash
docker-compose up -d
```

This starts four containers:

| Container | Role |
|---|---|
| `elasticsearch` | Persists all Copilot metrics in 7+ indexes |
| `grafana` | Serves the Grafana dashboard on port 8080 |
| `cpuad-updater` | Fetches data from GitHub APIs hourly and writes to Elasticsearch |
| `init-grafana` | One-shot: seeds Grafana datasources and dashboards on first run |

> **First run** takes ~2–3 minutes for all containers to reach healthy status.

---

## Phase 3 — Validate Core Behavior Locally

### 3a — Confirm all containers are healthy

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Expected output (all containers `Up` and/or `healthy`):

```
NAMES             STATUS
grafana           Up X minutes (healthy)
elasticsearch     Up X minutes (healthy)
cpuad-updater     Up X minutes
init-grafana      Exited (0) X minutes ago
```

> `init-grafana` should be `Exited (0)` — exit code 0 means it succeeded.

### 3b — Confirm Grafana is reachable

Open **http://localhost:8080** in your browser.  
Login: `admin` / `copilot` (or the values you set in `.env`).

You should see the pre-provisioned dashboards under **Dashboards**.

### 3c — Check `cpuad-updater` logs for successful API fetch

```bash
docker logs cpuad-updater --tail 40
```

Look for lines indicating a successful fetch and Elasticsearch write, for example:

```
INFO  Fetching metrics for org: your-org-name ...
INFO  Indexed X documents to copilot_usage_total
INFO  Indexed X documents to copilot_user_metrics
INFO  Next run in 1 hour(s)
```

If you see HTTP 401 or 403 errors, your `GITHUB_PAT` is invalid or missing required scopes.  
If you see connection errors to `elasticsearch:9200`, the Elasticsearch container may still be initializing — wait 60 seconds and check again.

### 3d — Check `init-grafana` logs for dashboard setup

```bash
docker logs init-grafana
```

Look for `Grafana setup complete` or similar success messages.

### 3e — Trigger an immediate data refresh (skip the 1-hour wait)

Restart `cpuad-updater` to force an immediate fetch:

```bash
docker restart cpuad-updater
docker logs cpuad-updater -f
```

### 3f — Verify data in Grafana

In Grafana, open any dashboard panel and check that data is visible. If the panels show "No data", either:
- Wait a few minutes for the updater to complete its first run, or
- Trigger a restart as described in 3e above.

---

## Phase 4 — Deploy to Azure (optional)

Deploy to Azure only when you need shared/managed hosting, production readiness, or CI/CD integration. **Local validation should pass first.**

Follow the full guide: **[docs/azd-up-guide.md](./azd-up-guide.md)**

### TL;DR

```bash
# Install Azure Developer CLI and Azure CLI if not already installed
azd auth login
az login

azd env new <your-environment-name>
azd env set GITHUB_PAT "ghp_your_token_here"
azd env set GITHUB_ORGANIZATION_SLUGS "your-org-name"
azd env set GRAFANA_PASSWORD "a-secure-password"

azd up
```

> ⏱ First deployment typically takes **15–25 minutes**.

---

## Phase 5 — Validate Azure Deployment

### 5a — Get the Grafana URL

```bash
azd env get-values | grep GRAFANA_DASHBOARD_URL
```

Open the URL in your browser and log in.

### 5b — Verify container app jobs are running

```bash
az containerapp list --resource-group <your-rg> --output table
```

All apps (`elasticsearch`, `grafana`) should show `Running`.

### 5c — Check cpuad-updater job logs

```bash
az containerapp logs show \
  --name cpuad-updater \
  --resource-group <your-rg> \
  --tail 50
```

### 5d — Trigger an immediate data refresh

```bash
# Linux/macOS
./scripts/deploy-azure-container-app-job-cpuad-updater.sh

# Windows
.\scripts\Deploy-AzureContainerAppJob-CpuAdUpdater.ps1
```

---

## Quick-Reference Validation Commands

```bash
# Check all containers are running
docker ps

# Tail updater logs in real-time
docker logs cpuad-updater -f

# Tail init-grafana logs
docker logs init-grafana

# Restart updater to force immediate data fetch
docker restart cpuad-updater

# Stop and remove all containers and volumes (full reset)
docker-compose down -v

# Rebuild containers after code changes
docker-compose up -d --build

# Validate Python source compiles (no Docker needed)
python -m compileall src/cpuad-updater
```

---

[Home](../README.md) | [Run Locally](./run-locally.md) | [Deploy with azd](./azd-up-guide.md)
