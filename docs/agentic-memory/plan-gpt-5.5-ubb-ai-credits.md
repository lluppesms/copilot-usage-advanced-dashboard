# GPT 5.5 Implementation Plan: PRU → UBB AI Credits

## Goal
Refactor the dashboard pipeline to prioritize **AI credit usage by individual user** and show **credit consumption patterns**, not money.

## Phase 1 — Data Contract
1. Define canonical AI-credit fields used across ETL/index/dashboard:
   - identity: `organization_slug`, `user_login`, `assignee_team_slug`, `day`
   - consumption: `ai_credits_net`, `ai_credits_gross`, `unit_type`, `quantity_raw`
   - attribution: `product`, `sku`, `model`
   - context: `used_chat`, `used_agent`, interactions/acceptances/generation
2. Set cost fields as non-display fields and exclude from dashboard transformations.

## Phase 2 — Extraction in `main.py`
1. Add API fetch path for AI credit usage in `GitHubOrganizationManager`.
2. Support org and enterprise endpoints.
3. Add parameter support for day/month/year and optional user/model/product filters.
4. Add retry and partial-failure behavior that does not break existing usage ingestion.

## Phase 3 — Transform and Enrich
1. Normalize billing records into line-item docs with stable IDs.
2. Reuse existing `user_team_lookup` from seat assignments to enrich each user credit record.
3. Join lightweight behavior context from `copilot_user_metrics` for “how they consume credits.”
4. Build two aggregate views:
   - per-user/day credits
   - per-user period summary with ranking fields

## Phase 4 — Indexes and Mappings
1. Add new indexes through `Indexes` class + mapping files:
   - `copilot_ai_credit_usage`
   - `copilot_ai_credit_user_daily`
   - `copilot_ai_credit_user_summary`
2. Keep existing indexes untouched for compatibility.
3. Ensure all credit indexes include date and keyword fields optimized for Grafana terms/date-histogram queries.

## Phase 5 — Grafana Datasource + Panels
1. Register new datasources in `/src/cpuad-updater/grafana/update_grafana.py`.
2. Add user-focused AI-credit panels in dashboard template:
   - total credits, active users, avg credits/user
   - daily credit trend
   - top users by credits
   - credits by model and product/SKU
   - user detail table with credits/day and behavior context
3. Keep existing behavior panels as complementary analytics.

## Phase 6 — Migration Strategy
1. Introduce feature flag for AI-credit ingestion/panels.
2. Deploy additive indexes and run initial backfill.
3. Validate in parallel with existing dashboard behavior.
4. Promote AI-credit row to primary and demote legacy PRU-style framing.

## Phase 7 — Quality and Validation
1. Data-level checks:
   - sum reconciliation between line-item and rollup indexes
   - idempotent writes across reruns
2. Dashboard-level checks:
   - filters by org/team/user/model/product
   - panel correctness for selected ranges
3. Policy checks:
   - no monetary labels/units in final dashboards

## Phase 8 — Operationalization
1. Add env vars for:
   - index names
   - lookback/backfill window
   - API version
   - enable flag
2. Update docs:
   - `.env.template`
   - local/deployment guides
   - version history
3. Add runbook notes for scope/permission failures and data-lag expectations.

## Risks
- API schema variability in unit fields
- missing user-level granularity in some billing responses
- identity mismatch between billing usernames and seat-assignment logins

## Clarifications Needed
1. Preferred default ranking metric: total credits vs credits per active day?
2. Required historical depth for migration reporting?
3. Whether cost-center views should be included from day one?
