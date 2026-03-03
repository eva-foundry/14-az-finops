# MARCO-INVENTORY Architecture & Data Model Integration

## Visual: Resource Flow Through EVA Architecture

```
                  AZURE SUBSCRIPTION (d2d4e571-...)
                           |
                  EsDAICoE-Sandbox RG
                           |
          +------------------+------------------+
          |                  |                  |
      marco*            non-marco           orphaned
      (24 resources)    (1186 resources)   (tracked)
          |
          |  [Get-MarcoInventory.ps1]
          |  (discover phase)
          |
          v
    MARCO-INVENTORY-*.md
    (static snapshot, Feb 13 2026)
    ├─ 24 resources by type
    ├─ 2 regions (canadacentral, canadaeast)
    └─ cost estimation (stub)
          |
          |  [Manual Review + Impact Analysis]
          |  (analyze phase)
          |
          +---------> PLAN.md (each project)
          |           "Which resources do we use?"
          |
          |  [Register in Data Model]
          |  (PUT /model/infrastructure/{id})
          |
          v
    EVA DATA MODEL (ACA Cosmos-backed, 24x7)
    Layer: Infrastructure (32 layers total)
    ├─ Projects (54 repos)
    ├─ Services (15 running services)
    ├─ Endpoints (290+ routes)
    ├─ Screens (30+ React components)
    ├─ Containers (8 Cosmos DBs)
    ├─ INFRASTRUCTURE <-- YOU ARE HERE
    │  ├─ id: "marcofinopsadx"
    │  ├─ type: "data_explorer_cluster"
    │  ├─ service: "finops-hub"
    │  ├─ status: "active"
    │  └─ is_active: true
    ├─ WBS (work breakdown structure)
    ├─ Evidence (immutable audit trail)
    └─ [25 more layers]
          |
          |  [Query Interface]
          |  GET /model/infrastructure/?service=finops-hub
          |  GET /model/impact/?resource=marco-eva-data-model
          |
          v
    AGENT/TOOL QUERIES (one HTTP call beats 10 file reads)
    ├─ "What resources does finops-hub use?" → [list]
    ├─ "What breaks if Cosmos fails?" → [impact: 8 services]
    ├─ "Cost by service?" → [attribution table]
    └─ "Who provisioned this & when?" → [audit trail]
          |
          v
    PROJECT DECISIONS (informed, data-driven)
    ├─ Strategic: FinOps Toolkit integration
    ├─ Tactical: Phase 3 APIM telemetry pipeline
    └─ Operational: AOE weekly recommendations
```

---

## Data Flow: Project 14 Example

### Current State (Phase 3 IN PROGRESS)

```
Azure Cost Export                 Project 14 Resources
(Cost Management API)
    |
    v
EsDAICoESub + EsPAICoESub
(10 consecutive runs + backfill)
    |
    +---------> marcosandboxfinopshub (Blob Storage)
    |           ├─ raw/ (CSV files)
    |           ├─ archive/ (90d Cool)
    |           └─ checkpoint/ (180d Archive)
    |
    +---------> marcosandboxfinopshub (Event Grid)
         	  └─ triggers on blob create
    |
    v
marco-sandbox-finops-adf (Data Factory)
    |
    +---------> ingest-costs-to-adx pipeline
    |           ├─ Read: blob CSV (RFC4180 escaped)
    |           └─ Write: ADX raw_costs table
    |
    v
marcofinopsadx (ADX Cluster)
    |
    ├─── KQL: raw_costs (table)
    ├─── KQL: CostExportMapping (table)
    ├─── KQL: NormalizedCosts() (v2 function)
    │    └─ Outputs: normalized schema + ESDC dims
    │       460K rows, 99.997% tag coverage
    │
    ├─── KQL: AllocateCostByApp() (function)
    │    └─ Routes costs to EVA-JP apps
    │
    └─── KQL: AllocateCostByAPI() (stub)
         └─ BLOCKED: Needs APIM telemetry (Phase 3)
             [TBD: Wire APIM policy → Log Analytics → ADX]

ERROR STATES (Documented Blockers)
├─ ❌ SDK pagination >5K rows
├─ ❌ Contributor role needed for provider registration
├─ ❌ APIM telemetry pipeline not deployed (Phase 3)
└─ ❌ FinOps Toolkit Power BI not wired (Phase 3/4)

DATA MODEL TRACKING (Infrastructure Layer)
├─ marcofinopsadx
│  ├─ id: "marcofinopsadx"
│  ├─ type: "data_explorer_cluster"
│  ├─ service: "finops-hub"
│  ├─ cosmos_reads: [] (ADX is read-only for now)
│  └─ cosmos_writes: []
│
├─ marco-sandbox-finops-adf
│  ├─ id: "marco-sandbox-finops-adf"
│  ├─ type: "data_factory"
│  ├─ service: "finops-hub"
│  └─ cosmos_reads: ["marcosandboxfinopshub"]
│
└─ marcosandboxfinopshub
   ├─ id: "marcosandboxfinopshub"
   ├─ type: "blob_storage"
   ├─ service: "finops-hub"
   └─ is_active: true
```

---

## Query Patterns: MARCO-INVENTORY vs Data Model

### Use Case 1: "What resources are in scope for project 14?"

**MARCO-INVENTORY Approach** ❌
```markdown
1. Open MARCO-INVENTORY-20260213-155026.md
2. Search for "marco-" + filter by region + grep for "finops"
3. Manual matching against PLAN.md
4. Result: Markdown table (static, possibly wrong)
```

**Data Model Approach** ✅
```powershell
$base = "https://marco-eva-data-model...."
$infra = Invoke-RestMethod "$base/model/infrastructure/?service=finops-hub"
$infra | Select-Object id, type, location, status

# Result:
# id: marcofinopsadx, type: data_explorer_cluster, location: canadacentral, status: active
# id: marco-sandbox-finops-adf, type: data_factory, location: canadacentral, status: active
# id: marcosandboxfinopshub, type: blob_storage, location: canadacentral, status: active
```

**Advantage**: Real-time, queryable, no manual matching

---

### Use Case 2: "What breaks if marcofinopsadx goes down?"

**MARCO-INVENTORY Approach** ❌
```markdown
1. Find marcofinopsadx in resource list
2. Grep PLAN.md & README.md for dependencies
3. Check ADF pipeline config manually
4. Result: Incomplete list, liable to drift
```

**Data Model Approach** ✅
```powershell
$base = "https://marco-eva-data-model...."
$impact = Invoke-RestMethod "$base/model/impact/?resource=marcofinopsadx"
$impact | Select-Object dependent_services, affected_endpoints, blocked_stories

# Result:
# dependent_services: ["finops-hub-api"]
# affected_endpoints: ["GET /api/costs", "GET /api/anomalies", "POST /api/chargeback"]
# blocked_stories: ["F14-06-004" (Phase 3: APIM Attribution)]
```

**Advantage**: Complete dependency graph, impact prediction

---

### Use Case 3: "What's the total monthly cost for 'finops-hub' service?"

**MARCO-INVENTORY Approach** ❌
```markdown
1. Find all resources tagged with project=finops-hub
2. Invite Azure Cost Management manually
3. Estimate: storage + ADX compute + ADF pipeline
4. Result: Manual estimate, no accuracy
```

**Data Model Approach** ✅
```powershell
$base = "https://marco-eva-data-model...."
$cost = Invoke-RestMethod "$base/model/cost-attribution/?service=finops-hub&period=month"
$cost | Select-Object service, total_cost, by_resource

# Result: [Real-time or cached from billing API]
# finops-hub total: $245/mo
#   - marcofinopsadx (compute): $180/mo
#   - marco-sandbox-finops-adf (orchestration): $45/mo
#   - marcosandboxfinopshub (storage lifecycle): $20/mo
```

**Advantage**: Accurate, automated, no manual estimation

---

## Key Insight: Data Model as Single Source of Truth

```
PRINCIPLE: "The data model is the single source of truth for all 
technical entities. One HTTP call beats 10 file reads."
```

**Why?**
- MARCO-INVENTORY: Fresh scan ≈ 1 week cycle (discovery phase cost: manual)
- Data Model: Real-time API (discovery phase cost: zero—already in Cosmos)
- MARCO-INVENTORY: Scope = all marco* (includes orphaned, unused, expired)
- Data Model: Scope = active project resources only (no noise)

**For Project 14 Specifically**:
- MARCO-INVENTORY tells you: "These 24 resources exist in subscription"
- Data Model tells you: "These 3 resources belong to finops-hub AND here's 
  the complete impact graph, cost attribution, and deployment order"

---

## Session Brief: Project 14 Bootstrap

```
[INFO] Bootstrap session starting March 3, 2026

PROJECT: 14-az-finops (Azure FinOps — ESDC Cost Management)
PHASE: Phase 3 IN PROGRESS (2/4 complete; APIM telemetry blocker)
MATURITY: empty (project marked "inactive" in workspace registry)
TESTS: Not tracked (operations-focused, no test framework)
NEXT: Phase 3 completion → Wire APIM telemetry pipeline → ADX attribution

BLOCKERS:
  [1] APIM telemetry pipeline not deployed (Phase 3 critical path)
  [2] FinOps Toolkit Power BI reports not wired (Phase 3/4 enhancement)
  [3] Azure Optimization Engine not deployed (Phase 4 dependency)
  [4] FOCUS schema not validated (Phase 4 quality gate)

DATA SOURCES:
  - Infrastructure Resources: 24 marco* (MARCO-INVENTORY snapshot)
  - Project Registry: Data Model `/model/infrastructure/?service=finops-hub` (🟡 NOT VERIFIED YET)
  - Cost Data: 460K normalized records in ADX (99.997% tag coverage)
  - Problem Data: Advanced-Capabilities-Showcase.md (12 analytics + 8 ops use cases)

GATES:
  - Phase 3 readiness: APIM policy + telemetry pipeline complete
  - Data quality: Validate NormalizedCosts() v2 on Production export (in progress)
  - FinOps Toolkit discovery: 5 components mapped, 3 integration gaps identified

ACTION ITEMS:
  1. Verify 14-az-finops resources registered in data model Infrastructure layer
  2. Unblock Phase 3: Complete APIM telemetry pipeline design
  3. Prioritize Phase 4: AOE deployment vs toolkit Power BI wiring
```

---

## Files Referenced

| File | Path | Purpose |
|------|------|---------|
| MARCO-INVENTORY | `.eva-cache/current/MARCO-INVENTORY-20260213-155026.md` | Resource snapshot (14d old) |
| Project 14 PLAN | `14-az-finops/PLAN.md` | Current phase + story breakdown |
| Project 14 README | `14-az-finops/README.md` | Setup guide + FinOps Toolkit discovery |
| Advanced Capabilities | `14-az-finops/docs/ADVANCED-CAPABILITIES-SHOWCASE.md` | 12 analytics + 8 ops ready to deploy |
| Data Model API | https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io | Infrastructure layer (32 total layers) |
