# Rubber-Duck Comparison + Combined Best-Practices Plan

## Comparison Summary

### Where Opus 4.7 was stronger
- More explicit end-to-end sequencing across ETL, schema, Grafana, rollout.
- Better treatment of operational concerns (idempotency, overlap fetch, graceful degradation).
- Stronger risk framing and compatibility strategy.

### Where GPT 5.5 was stronger
- Clear data-contract-first framing.
- Cleaner phased plan structure for handoff execution.
- Focused emphasis on keeping cost fields non-display while preserving raw source fidelity.

## Combined Best-Practices Plan (Implementation-Ready)

## 1) Define the AI-Credit Data Contract (first)
Establish canonical fields and naming used across extraction, ES mappings, and Grafana:
- identity: `organization_slug`, `slug_type`, `user_login`, `assignee_team_slug`, `day`
- attribution: `product`, `sku`, `model`, `unit_type`
- consumption: `quantity_raw`, `ai_credits_net`, optional `ai_credits_gross`
- context: `used_chat`, `used_agent`, interaction/completion/acceptance metrics

Rule: cost/currency fields may be stored for audit but never surfaced in dashboard UI.

## 2) Add Billing Extraction Path in `src/cpuad-updater/main.py`
- Extend `GitHubOrganizationManager` with AI credit usage fetch methods for org + enterprise scopes.
- Integrate fetch block after seat assignment and user metrics enrichment are available.
- Reuse common request/retry handling patterns.
- Add feature flag + scope checks so missing billing access does not break existing workflows.

## 3) Build Credit Transform + Aggregation Layers
- Normalize line items with deterministic `unique_hash` for idempotent writes.
- Enrich each credit record with `assignee_team_slug` via existing seat lookup.
- Produce two rollups:
  1. user/day credit totals and top consumption dimensions
  2. user/range summary with ranking metrics
- Include “how consumed” attributes (model/product/SKU + chat/agent context).

## 4) Add New Mappings and Indexes
Create mapping files in `/src/cpuad-updater/mapping/` and add index constants:
- `copilot_ai_credit_usage`
- `copilot_ai_credit_user_daily`
- `copilot_ai_credit_user_summary`

Design goals:
- date fields for time filtering
- keyword fields for grouping/filtering
- numeric fields for credits and derived metrics
- additive only; no destructive changes to existing indexes

## 5) Update Grafana Data Sources and Dashboard
Files:
- `/src/cpuad-updater/grafana/update_grafana.py`
- `/src/cpuad-updater/grafana/dashboard-template.json`

Add AI-credit-focused panels:
- total credits
- active credit users
- avg credits per active user
- daily credit trend
- top users by credits
- credits by model/product/SKU
- per-user detailed table and drilldown

Retain existing behavior panels as context for adoption and interaction patterns.

## 6) Migration & Rollout Strategy
1. Ship schema + ETL behind feature flag.
2. Run limited backfill and reconcile totals.
3. Add dashboard row collapsed by default.
4. Validate with stakeholders and make AI-credit row primary.
5. Keep legacy metrics available until confidence is established.

## 7) Validation Plan
- ETL idempotency (re-run should not inflate totals).
- Aggregation reconciliation (line items == daily == summary totals).
- Dashboard query correctness with org/team/user filters.
- Regression validation for unchanged existing panels.
- Policy validation: no currency labels/units or cost metrics displayed.

## 8) Documentation & Handoff Deliverables
Update deployment and config docs to include:
- required billing scopes
- new environment variables
- expected billing data lag/backfill behavior
- troubleshooting checklist for empty credit panels

Handoff package for implementation team:
1. Data contract and field dictionary
2. File-by-file change list
3. Ordered execution phases with exit criteria
4. Validation checklist and acceptance criteria

## Clarifying Questions Before Implementation
1. Should source-of-truth billing be organization-level, enterprise-level, or both?
2. What historical backfill window is mandatory?
3. Should inactive users with zero credits appear in user reports?
4. Do we need cost-center segmentation in v1 of this conversion?
