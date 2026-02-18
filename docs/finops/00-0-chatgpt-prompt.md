# TASK: Marcosandbox FinOps Enterprise Roadmap – Evidence-based Inventory + Gap Plan (FinOps Hubs + APIM attribution)

You are Copilot acting as a senior Azure FinOps + Cloud Architecture engineer.

Context:
- We have Azure Cost Management exports for BOTH subscriptions (esdaicoesub + espaicoesub) since Feb 2025.
- The raw exports are currently stored as CSVs in Cosmos DB container: marcosandboxfinopshub / costs (13 x 2 exports).
- APIM exists/being implemented; resources have tags; we want enterprise cost allocation/showback/chargeback (CostCenter/App/Env etc.).
- Target architecture: Cost exports -> ADLS Gen2 -> Event Grid -> FinOps Hubs pipelines -> ADX (Kusto) -> Power BI KQL templates
  PLUS join with APIM usage telemetry (headers/caller app/cost center) for allocation.

Your job:
1) Gather EVIDENCE from the codebase + Azure resources (via az cli scripts or ARM/Bicep/Terraform files in repo), and output:
   - Current state inventory (what exists right now in marcosandbox)
   - Gaps vs FinOps Hubs enterprise reference
   - Proposed deployment plan (what to deploy, where, why)
   - ADO-ready backlog (Epics/Features/Tasks) with acceptance criteria
2) Do NOT guess. If you can’t find a fact, explicitly label it as “UNKNOWN” and propose how to confirm it.

Deliverables (create these files in /docs/finops/):
A) docs/finops/00-current-state-inventory.md
B) docs/finops/01-gap-analysis-finops-hubs.md
C) docs/finops/02-target-architecture.md  (include diagram in Mermaid)
D) docs/finops/03-deployment-plan.md       (phased, IaC-first)
E) docs/finops/04-backlog.md               (Epics/Features/Tasks + AC)
F) docs/finops/05-evidence-pack.md         (commands run, outputs captured, screenshots refs, etc.)

Step 0 — Repo inspection (evidence):
- Find any existing FinOps Toolkit or hubs deployments, templates, scripts, pipelines.
- Locate APIM deployment code, logging/telemetry, tagging conventions, cost headers.
- Locate Cosmos DB container usage (why CSVs are there) and any ETL code.

Step 1 — Azure inventory scripts (produce scripts under /tools/finops/):
Create scripts that can be run from DevBox with az cli:
- tools/finops/az-inventory-finops.ps1 (or .sh)
  Must output (as JSON files under /out/):
  1) subscriptions, resource groups relevant to marcosandboxfinopshub
  2) storage accounts + containers + network settings (public access, private endpoints)
  3) ADX clusters/databases/tables (if any)
  4) ADF factories/pipelines/triggers (if any)
  5) Event Grid topics/subscriptions (if any)
  6) APIM instances, APIs, products, policies, diagnostics, loggers
  7) App Insights / Log Analytics workspaces
  8) Key Vaults + secrets used
  9) Managed identities + role assignments relevant to exports, storage, ADX, ADF, APIM
  10) Cost Management exports configuration per subscription (if visible), and destination storage (if any)

For each “az” command, write it in the script AND write where the output is stored under /out/.
If some inventory requires subscription-level permissions, note it clearly.

Step 2 — FinOps Hubs reference mapping (gap analysis):
Using Microsoft FinOps Toolkit Hubs concept:
- Identify minimum required Azure resources for Hubs:
  - ADLS Gen2 landing zone for exports
  - Event Grid trigger wiring
  - ADF pipelines for ingestion/normalization
  - ADX cluster + database (or Fabric RTI if chosen, but default to ADX)
  - RBAC roles for exports + ingestion + query + Power BI access
- Compare to our inventory and list exactly what’s missing in marcosandbox.

Step 3 — Cosmos situation:
- Explain (based on code) why exports were written to Cosmos.
- Propose the migration path:
  - Option 1: rebuild exports to land directly to ADLS Gen2 going forward + backfill historical from Cosmos -> ADLS
  - Option 2: keep Cosmos as staging but replicate to ADLS as a hub landing zone
Pick one as recommended, with reasons (enterprise alignment + tooling compatibility).

Step 4 — APIM attribution integration:
- Identify whether APIM policies already inject cost attribution headers (e.g., x-eva-costcenter, x-caller-app, x-env, x-user-role).
- Identify where telemetry is being logged (App Insights / Log Analytics) and if logs capture those headers.
- Propose the minimum join model for allocation:
  - ADX table for usage telemetry keyed by timestamp + subscription/resource + caller/app/costcenter
  - ADX queries/functions to allocate Azure spend to callers/apps where possible
Also define required tag taxonomy and enforcement points (APIM policy + Azure Policy).

Step 5 — Target architecture + plan:
- Produce a phased plan:
  Phase 1: Stand up Hubs foundation (storage + event grid + ADF + ADX) and connect Power BI KQL templates
  Phase 2: Backfill historical exports (from Cosmos -> ADLS -> ADX)
  Phase 3: APIM attribution headers + telemetry table in ADX + allocation views
  Phase 4: Governance hardening (private endpoints, RBAC, policies, CI/CD)
Each phase must have acceptance criteria and evidence expected.

Constraints:
- Enterprise best practices: private networking where feasible, least privilege RBAC, tagging & cost allocation, auditability.
- Use IaC-first (Bicep/Terraform) and document required parameters.
- Provide clear “what to deploy in marcosandbox” list (resource names, RG names, dependencies).
- Do not include any secrets.

Output style:
- Structured bullet lists + tables where useful.
- Every major claim must reference evidence: file paths, command outputs, or existing resource IDs.
- If something cannot be validated, mark it UNKNOWN and list the exact next check.

Start now by scanning the repo and generating Deliverables A–F with placeholders, then implement the inventory scripts, then fill in inventory + gap analysis from evidence.
