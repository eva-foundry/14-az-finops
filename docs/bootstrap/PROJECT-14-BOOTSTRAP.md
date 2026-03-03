# Project 14 Bootstrap & MARCO-INVENTORY Integration

**Date**: March 3, 2026  
**Context**: Project 14 (Azure FinOps) + Understanding MARCO-INVENTORY in the Data Model  
**Status**: 🟡 Phase 3 IN PROGRESS | Phases 1-2 Complete

---

## PART A: PROJECT 14 BOOTSTRAP

### Project Identity

| Field | Value |
|-------|-------|
| **ID** | 14-az-finops |
| **Name** | Azure FinOps — ESDC Cost Management |
| **Maturity** | *empty* (listed as inactive in workspace registry) |
| **Scope** | EsDAICoESub + EsPAICoESub (ESDC Production) + 50+ EVA-JP APIs |
| **Last Updated** | March 2, 2026 5:38 PM ET |
| **Owner** | marco.presta@hrsdc-rhdcc.gc.ca (Cost Management Contributor + Reader) |

### Project Overview

**Purpose**: Build enterprise FinOps (Financial Operations) platform for ESDC using:
- **Data Pipeline**: Azure Data Factory (ADF) + Azure Data Explorer (ADX) + Azure Data Lake Storage (ADLS Gen2)
- **Cost Export**: Microsoft Cost Management SDK + automated exports to 3 ESDC subscriptions
- **Cost Attribution**: Normalize raw costs, allocate by team/app, APIM per-API chargeback
- **Governance**: FinOps Toolkit discovery + FOCUS schema alignment (Phase 4)

**Budget**: $567K total collected; steady-state ~$318K/yr after anomalies  
**Quick Wins**: $103K/yr identified in [Advanced-Capabilities-Showcase.md](docs/ADVANCED-CAPABILITIES-SHOWCASE.md)

### Deployment Status (DPDCA Phases)

| Phase | Status | Key Deliverables | Completion Date |
|-------|--------|------------------|-----------------|
| **Phase 0** | DONE | Data collection foundation; 10 export runs verified | Feb 16, 2026 |
| **Phase 1** | DONE | Containers + lifecycle policy; 28 blobs migrated | Feb 25, 2026 |
| **Phase 2** | DONE | ADX cluster + ADF pipeline; schema deployed; backfill triggered | Feb 26, 2026 |
| **Phase 3** | IN PROGRESS | NormalizedCosts() v2 deployed (tag bug fixed); APIM telemetry pipeline pending | Mar 2, 2026 |
| **Phase 4** | PLANNED | Azure Optimization Engine; FinOps Toolkit Power BI wiring; FOCUS validation |

### What Works Now ✅

1. **Cost Export Pipeline**
   - SDK exports to: EsDAICoESub + EsPAICoESub
   - 10 consecutive runs verified + backfill of 28 historical blobs done
   - RFC4180 CSV escaping fixed (safe)

2. **Data Infrastructure**
   - ADX cluster: `marcofinopsadx` (Dev SLA, canadacentral)
   - ADF pipeline: `ingest-costs-to-adx` wired to Event Grid (auto-triggers on new blobs)
   - ADLS Gen2: `marcosandboxfinopshub` (raw/archive/checkpoint containers)
   - Lifecycle policy: 90d Cool, 180d Archive auto-configured

3. **Cost Normalization**
   - `NormalizedCosts()` KQL function (v2): Converts raw CSV → normalized schema
   - Tag coverage: 99.997% (460,594/460,609 rows)
   - ESDC dimensions: SSC+Legacy schemas, CanonicalEnvironment, 6 ESDC-specific fields

4. **Cost Attribution**
   - `AllocateCostByApp()` KQL function: Routes costs to EVA-JP apps
   - Per-team chargeback visibility ready

5. **Observability**
   - Advanced-Capabilities-ShowCase.md: 12 analytics + 8 operational use cases documented

### What Does NOT Work ❌

1. **APIM Cost Attribution** (Phase 3 blocker)
   - Need per-API APIM telemetry pipeline → ADX
   - Then AttributeCostByAPI() KQL function
   - Current: Manual fallback attribution

2. **Azure Optimization Engine** (Phase 4 dependency)
   - Not deployed yet
   - Needed for weekly auto-recommendations (VM sizing, orphaned resources)

3. **FinOps Toolkit Power BI Reports** (Phase 3/4 enhancement)
   - Toolkit provides 5 pre-built reports (charge breakdown, recommendations, governance)
   - Not wired to your ADX schema yet
   - Integration path: Toolkit reports → your normalized_costs table

4. **SDK Limitations**
   - Cost Management SDK pagination: >5K rows requires manual batching
   - Provider registration blocked without Contributor role (you have Cost Management Contributor only)

### Project Structure

```
14-az-finops/
├── scripts/
│   ├── adf/                  # Data Factory automation
│   │   ├── create-eventgrid-subscription.ps1
│   │   ├── deploy-functions.ps1
│   │   └── ...
│   ├── kql/                  # Kusto Query Language functions & ingestion
│   │   ├── 01-create-schema.kql      # Tables: raw_costs, CostExportMapping, etc.
│   │   ├── 02-normalized-costs.kql   # NormalizedCosts() v2
│   │   ├── 03-allocate-cost-by-app.kql  # AllocateCostByApp()
│   │   └── ...
│   └── bicep/                # Infrastructure as Code
│       ├── adx-cluster.bicep
│       ├── managed-identity.bicep
│       └── lifecycle-policy.json
├── docs/
│   ├── ADVANCED-CAPABILITIES-SHOWCASE.md    # 12 analytics + 8 ops use cases
│   ├── saving-opportunities.md              # $80K+ quick wins identified
│   └── ...
├── PLAN.md                   # Current phase status (veritas-normalized F14-* IDs)
├── README.md                 # Full setup guide + FinOps Toolkit discovery
└── .github/
    └── copilot-instructions.md  # v2.1.0 template
```

### Active Subscriptions

| Subscription | ID | Status | Resources |
|---|---|---|---|
| **EsDAICoESub** | `d2d4e571-e0f2-4f6c-901a-f88f7669bcba` | ACTIVE | 24 marco* resources + 1210 total |
| **EsPAICoESub** | `802d84ab-...` | SCOPED | FinOps Hub storage only |

---

## PART B: MARCO-INVENTORY & DATA MODEL INTEGRATION

### What is MARCO-INVENTORY?

**File**: `C:\AICOE\eva-foundry\system-analysis\inventory\.eva-cache\current\MARCO-INVENTORY-20260213-155026.md`

**Purpose**: Snapshot of all Azure resources matching `marco*` naming pattern in EsDAICoE-Sandbox resource group.

**Content**:
- 24 resources across 2 regions (canadacentral, canadaeast)
- Generated from: `azure-inventory-EsDAICoESub-20260211-092125.json`
- Includes: Cognitive Services (5), Web Apps (3), Storage (2), Cosmos DB (1), ADX (via ADA Hubs), APIM, ACR, Key Vault, Event Grid, etc.

### How MARCO-INVENTORY Relates to the Data Model

#### Layer 1: Infrastructure Registry (data-model `/model/infrastructure/`)

The **EVA Data Model** includes an **Infrastructure Layer** (32 layers total) that catalogs:

```
GET /model/infrastructure/ → Returns all Azure resources with:
├── id               (resource name: "marco-eva-data-model", etc.)
├── type             ("cosmos_db", "container_app", "blob_storage", etc.)
├── azure_resource_name  (full ARM resource ID)
├── service          (which project service: "data-model-api", "eva-brain-api", etc.)
├── resource_group   ("EsDAICoE-Sandbox")
├── location         ("canadacentral", etc.)
├── status           ("active", "deprecated", "PoC")
├── is_active        (true/false)
└── provision_order  (deployment sequence for IaC)
```

#### Key Differences: MARCO-INVENTORY vs Data Model

| Aspect | MARCO-INVENTORY | Data Model Infrastructure Layer |
|--------|---|---|
| **Source** | Azure CLI: `az resource list --name 'marco*'` | Manually maintained API records |
| **Refresh** | On-demand script run (last: Feb 13, 2026) | Real-time via `PUT /model/infrastructure/{id}` |
| **Scope** | ALL marco* resources in subscription | ONLY resources associated with EVA projects |
| **Automation** | ❌ Manual CSV export | ✅ HTTP API + Cosmos DB backend |
| **Queryability** | 📄 Markdown tables (static snapshot) | ✅ Dynamic `?filter=` queries (status, service, type) |
| **History** | Snapshots in `.eva-cache/history/` | Full audit trail (created_at, modified_by, row_version) |
| **TTL** | Stale (15 days old) | Current (24x7 ACA-backed) |

### Integration Workflow

#### Step 1: Inventory Discovery (MARCO-INVENTORY)

**Script**: `Get-MarcoInventory.ps1` (from project's `scripts/` folder)

```powershell
# Runs quarterly or on-demand
$inv = Get-MarcoInventory -SubscriptionId "d2d4e571-..." -Filter "marco*"
# Output: MARCO-INVENTORY-20260213-155026.md + JSON source
# Then: Analyze cost tags, naming consistency, orphaned resources
```

**Output**: Markdown snapshot for human review + impact analysis

---

#### Step 2: Registration in Data Model (Infrastructure Layer)

When a new **marco-** resource is provisioned:

```powershell
# API call to register in data model
$ep = @{
    id = "marco-eva-data-model"
    type = "cosmos_db"
    azure_resource_name = "/subscriptions/d2d4e571-.../resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.DocumentDB/databaseAccounts/marco-eva-data-model"
    service = "data-model-api"        # Project service calling it
    resource_group = "EsDAICoE-Sandbox"
    location = "canadacentral"
    status = "active"
    is_active = $true
    provision_order = 1               # deploy Cosmos before data-model-api
}
$body = $ep | ConvertTo-Json
Invoke-RestMethod "https://marco-eva-data-model.../model/infrastructure/marco-eva-data-model" `
    -Method PUT -Body $body -Headers @{"X-Actor"="agent:copilot"}
```

**Data Model** then tracks:
- Which projects use which resources
- Dependency graph (Cosmos → ACA → APIM)
- Cost attribution by service
- Lifecycle (provisioned → active → archived)

---

#### Step 3: Documentation & Impact Analysis

**Query Infrastructure by Service**:

```powershell
# All resources used by project 33-eva-brain-v2
Invoke-RestMethod "https://marco-eva-data-model.../model/infrastructure/?service=eva-brain-api"
# Returns: GPT deployment, App Service, Cosmos reads/writes, managed identity, etc.

# Dependency graph: what breaks if Cosmos goes down?
Invoke-RestMethod "https://marco-eva-data-model.../model/impact/?resource=marco-eva-data-model"
# Returns: All services reading/writing to Cosmos DB + risk analysis
```

---

### Why Data Model > MARCO-INVENTORY

**Problem with Static Inventory** (MARCO-INVENTORY):
- 📆 Stale (snapshot at point-in-time)
- 📄 Human-maintained Markdown (error-prone)
- ❓ No query language (must read entire file)
- 🔗 No relationship graph (can't ask "what depends on this?")
- 📊 No cost attribution (raw resources, not mapped to projects)

**Data Model Solution** (`/model/infrastructure/`):
- ✅ Real-time (24x7 Cosmos-backed API)
- ✅ Query language (filter by service, type, status)
- ✅ Relationship graph (impact analysis)
- ✅ Cost attribution (resources → services → projects)
- ✅ Audit trail (who provisioned, when, cost change)

---

### Project 14 in the Data Model

For **14-az-finops**, the infrastructure layer should track:

```json
{
  "id": "marcofinopsadx",
  "type": "data_explorer_cluster",
  "service": "finops-hub",
  "resource_group": "EsDAICoE-Sandbox",
  "status": "active",
  "cosmos_writes": []  // (ADX is read-only from cost data)
},
{
  "id": "marco-sandbox-finops-adf",
  "type": "data_factory",
  "service": "finops-hub",
  "status": "active"
}
```

**Query**: "What resources feed project 14?"
```powershell
Invoke-RestMethod "https://marco-eva-data-model.../model/infrastructure/?service=finops-hub"
# Returns: ADX cluster, ADF pipeline, ADLS storage, Event Grid system topic
```

---

## PART C: Next Steps for Project 14

### Immediate (This Week)

1. **Verify Data Model Registration**
   ```powershell
   $base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"
   Invoke-RestMethod "$base/model/infrastructure/?service=finops-hub" | Select-Object id, type, status
   ```

2. **Check Phase 3 Blockers**
   - APIM telemetry pipeline status (needed for cost attribution by API)
   - ADX schema validation (NormalizedCosts v2 ready for Production?)

3. **Run Advanced-Capabilities Showcase** (optional prioritization)
   - Review 12 analytics use cases
   - Rank by value + effort for Phase 4 sprint

### Phase 3 (Current — Next 2 weeks)

1. **Deploy APIM Telemetry Pipeline**
   - Instruments 50+ EVA-JP APIs for per-call cost tracking
   - Outputs to ADX `apim_usage` table
   - Triggers `AllocateCostByAPI()` KQL function

2. **Fix Tag Bug in NormalizedCosts()**
   - You mentioned "tag bug fixed" in Phase 3 notes
   - Verify 99.997% tag coverage holds across production export

### Phase 4 (Planned — Weeks 8-12)

1. **Azure Optimization Engine (AOE)**
   - Deploy 5-min setup
   - Wire recommendations to ADX; correlate with your anomaly detection

2. **FinOps Toolkit Power BI Reports**
   - Wire 5 pre-built reports to your normalized_costs table
   - Charge breakdown, governance, rate-optimization views

3. **FOCUS Schema Alignment**
   - Validate `normalized_costs` against FOCUS 1.0 spec
   - Ensures future integration compatibility

---

## Quick Access

| Document | Purpose |
|----------|---------|
| [PLAN.md](c:\AICOE\eva-foundry\14-az-finops\PLAN.md) | Current phase status + story breakdown (veritas-normalized F14-* IDs) |
| [README.md](c:\AICOE\eva-foundry\14-az-finops\README.md) | Full setup guide + ADVANCED-CAPABILITIES-SHOWCASE.md link |
| [Advanced-Capabilities-Showcase.md](c:\AICOE\eva-foundry\14-az-finops\docs\ADVANCED-CAPABILITIES-SHOWCASE.md) | 12 advanced analytics + 8 ops use cases ready to deploy |
| [saving-opportunities.md](c:\AICOE\eva-foundry\14-az-finops\docs\saving-opportunities.md) | $80K+ quick wins already identified |
| MARCO-INVENTORY (this file) | Snapshot of 24 marco* resources (Feb 13, 2026) |

---

**End Bootstrap Document**
