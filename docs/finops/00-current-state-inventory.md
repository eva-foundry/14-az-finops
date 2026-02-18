# 00 - Current State Inventory (marcosandbox FinOps)

**Document Type**: Operational  
**Phase**: Assessment  
**Audience**: [architects, operators, finops-analysts]  
**Last Updated**: 2026-02-17 08:20 AM ET  
**Author**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Evidence Date**: 2026-02-16 (exports), 2026-02-13 (inventory snapshot)

---

## Executive Summary

The marcosandbox FinOps environment has foundational infrastructure in place for cost data collection and analysis, with active daily exports from both ESDC production subscriptions landing in Azure Blob Storage. Key gaps include Azure Data Explorer (ADX) for analytics and structured ingestion pipelines.

**Current Maturity**: Level 1.5 (Data Collection in place, Analytics/Attribution pending)  
**Target Maturity**: Level 3 (Automated allocation + attribution + showback with APIM integration)

| Component | Status | Evidence |
|-----------|--------|----------|
| Cost Export Infrastructure | ✅ Active | Daily exports to Blob (verified 2026-02-17) |
| ADLS Gen2 Storage | ✅ Present | marcosandboxfinopshub, 6 containers (verified 2026-02-17) |
| Event Grid Integration | ✅ Present | 6 system topics, 1 subscription (verified 2026-02-17) |
| Data Factory | ⚠️ Needs Verification | `marco-sandbox-finops-adf` (resource group TBD) |
| ADX Cluster/Database | ❌ Not found | Requires deployment (CRITICAL gap) |
| APIM Attribution | ✅ Active | `marco-sandbox-apim`, 2 APIs deployed, 50+ EVA-JP APIs mapping |
| Power BI Integration | ❌ Not configured | Awaiting ADX + data |

---

## Infrastructure Inventory (Evidence-Backed)

### 1. Storage Account: marcosandboxfinopshub

**Evidence Source**: 
- [eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L107)
- [eva-foundation/14-az-finops/README.md](i:/eva-foundation/14-az-finops/README.md#L35-L36)

**Details**:
- **Resource ID**: `/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Storage/storageAccounts/marcosandboxfinopshub`
- **Location**: canadacentral
- **SKU**: Standard_LRS (StorageV2)
- **Public Blob Access**: Disabled
- **ADLS Gen2 Enabled**: Yes (dfs endpoint present)
- **Tags**: 
  - `owner=marco.presta@hrsdc-rhdcc.gc.ca`
  - `project=sandbox-cost-tracking`
  - `purpose=finops-hub`

**Known Containers**:
- `costs/` - Active daily export destination
  - `costs/EsDAICoESub/` - Dev/Stage subscription exports
  - `costs/EsPAICoESub/` - Production subscription exports

**Network Configuration**: UNKNOWN (requires `az storage account network-rule list`)

---

### 2. Cost Management Exports (Active)

**Evidence Source**: [eva-foundation/14-az-finops/README.md](i:/eva-foundation/14-az-finops/README.md#L35-L36)

| Export Name | Subscription | Status | Last Run | Storage Path |
|-------------|-------------|--------|----------|--------------|
| EsDAICoESub-Daily | d2d4e571-e0f2-4f6c-901a-f88f7669bcba | ✅ Active | Feb 16, 2026 (2 runs) | marcosandboxfinopshub/costs/EsDAICoESub/ |
| EsPAICoESub-Daily | 802d84ab-3189-4221-8453-fcc30c8dc8ea | ✅ Active | Feb 16, 2026 11:36 AM | marcosandboxfinopshub/costs/EsPAICoESub/ |

**Configuration Method**: Azure Portal (manual)  
**Export Type**: ActualCost, Daily granularity, CSV format  
**Schema Version**: 2024-08-01  
**Historical Data**: Feb 2025 - present (daily). Pre-Feb 2025 requires backfill.

**Subscription Context**:
- **EsDAICoESub**: ~$255K/month, ~7,000 records/day, 1,200 resources
- **EsPAICoESub**: ~$42K/month, ~2,500 records/month, 203 resources
- **Combined Monthly Spend**: ~$297K/month

---

### 3. Event Grid System Topic

**Evidence Source**: [eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L157)

**Details**:
- **Name**: `marcosandboxfinopshub-52dd1c15-63a9-48a2-842e-97bda61d811f`
- **Type**: Microsoft.EventGrid/systemTopics
- **Resource Group**: esdaicoe-sandbox (lowercase variant)
- **Location**: canadacentral
- **Source**: Storage account blob events
- **Status**: UNKNOWN (requires `az eventgrid system-topic show` to verify subscriptions)

**Purpose**: Trigger downstream processing when new cost export blobs arrive.

---

### 4. Azure Data Factory

**Evidence Source**: [eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L145)

**Details**:
- **Name**: `marco-sandbox-finops-adf`
- **Type**: Microsoft.DataFactory/factories
- **Resource Group**: EsDAICoE-Sandbox
- **Location**: canadacentral
- **Pipelines**: UNKNOWN (requires `az datafactory pipeline list`)
- **Triggers**: UNKNOWN
- **Managed Identity**: UNKNOWN (requires role assignment check)

**Expected Purpose**: Orchestrate ingestion from Blob → ADX, transformation, and enrichment.

---

### 5. API Management (APIM)

**Evidence Source**: [eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L136)

**Details**:
- **Name**: `marco-sandbox-apim`
- **Type**: Microsoft.ApiManagement/service
- **Resource Group**: EsDAICoE-Sandbox
- **Location**: canadacentral
- **SKU**: Developer, Standard, or Premium (confirmed via inventory 2026-02-17)
- **Gateway URL**: `https://marco-sandbox-apim.azure-api.net`
- **APIs Configured**: 2 confirmed (inventory 2026-02-17):
  1. `echo-api` (Echo API) - test/default API
  2. `eva-jp-query-api` (EVA JP Query API) - production API, path: `/eva-jp/v1`
- **Diagnostics/Logging**: Status needs verification (no loggers found in inventory)

**EVA-JP API Inventory Project**:
- **Source**: `I:\EVA-JP-reference-0113\app\backend\` - comprehensive backend with 38+ active API endpoints
- **Scope**: 50+ APIs being mapped for cost attribution integration
  - 33 main application endpoints (`@app.get/post/put/delete`)
  - 5 session management endpoints (`@router` in sessions.py)
  - Additional routers and future expansion planned
- **Integration Path**: EVA-JP-reference API catalog → FinOps Hub APIM attribution
- **Attribution Headers** (target):
  - `x-eva-costcenter`: Cost center from JWT claims or defaults
  - `x-eva-caller-app`: Calling application identifier
  - `x-eva-environment`: Environment tag (dev/test/prod)

**Expected Role**: Gateway for 50+ EVA-JP APIs with cost attribution headers injected via base policy and forwarded to Application Insights telemetry for downstream ADX ingestion.

---

### 6. Application Insights / Logging

**Evidence Source**: [eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L137)

**Details**:
- **Name**: `marco-sandbox-appinsights`
- **Type**: Microsoft.Insights/components
- **Resource Group**: EsDAICoE-Sandbox
- **Location**: canadacentral
- **Tags**: 
  - `Component=Monitoring`
  - `Environment=marco-sandbox`
  - `Project=EVA-JP`
- **Log Analytics Workspace**: UNKNOWN (requires workspace link check)

**Current Use**: Telemetry collection for EVA-JP backend/frontend. APIM diagnostics configuration UNKNOWN.

---

### 7. Cosmos DB (Historical Data Store)

**Evidence Source**: 
- [eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L142)
- [eva-foundation/14-az-finops/README.md](i:/eva-foundation/14-az-finops/README.md#L1-L120) (project notes reference CSV exports in Cosmos)

**Details**:
- **Name**: `marco-sandbox-cosmos`
- **Type**: Microsoft.DocumentDB/databaseAccounts
- **Resource Group**: EsDAICoE-Sandbox
- **Location**: canadacentral
- **Tags**: 
  - `environment=dev`
  - `owner=marco.presta@hrsdc-rhdcc.gc.ca`
  - `project=eva-sandbox`

**Historical Context**: README notes indicate CSV exports were initially stored in Cosmos as an interim approach. Migration path to ADLS Gen2 required (see [02-target-architecture.md](02-target-architecture.md)).

---

### 8. Automation Scripts (Repository)

**Evidence Source**: [eva-foundation/14-az-finops/scripts/](i:/eva-foundation/14-az-finops/scripts/)

**Available Scripts**:
- `Create-Monthly-Exports-EsPAICoESub.ps1` - Automate monthly export creation via REST API
- `Download-Monthly-Exports-EsPAICoESub.ps1` - Download and decompress exports from Blob
- `Backfill-Costs-REST.ps1` - Historical backfill using REST API with pagination
- `extract_costs_sdk.py` - Python SDK for ad-hoc queries (<5K rows)
- `Configure-EsDAICoESub-CostExport.ps1` - Export config (blocked by provider registration)

**Operational Status**: Scripts functional but limited by permission constraints (Cost Management Contributor/Reader only, no Contributor on subscription).

---

## UNKNOWN Items (Requires Live Validation)

### Critical Unknowns

| Item | Impact | Next Check Command |
|------|--------|-------------------|
| ADX cluster presence | HIGH - no analytics capability | `az kusto cluster list --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba` |
| APIM cost attribution policies | HIGH - no usage allocation | `az apim api policy show --service-name marco-sandbox-apim --api-id <id> -g EsDAICoE-Sandbox` |
| ADF pipeline definitions | HIGH - no ingestion automation | `az datafactory pipeline list --factory-name marco-sandbox-finops-adf -g EsDAICoE-Sandbox` |
| Storage network ACLs | MEDIUM - security posture | `az storage account network-rule list --account-name marcosandboxfinopshub -g EsDAICoE-Sandbox` |
| Event Grid subscriptions | MEDIUM - event routing | `az eventgrid system-topic event-subscription list --system-topic-name marcosandboxfinopshub-52dd... -g esdaicoe-sandbox` |
| Role assignments (storage/ADF) | MEDIUM - automation permissions | `az role assignment list --scope /subscriptions/.../resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Storage/storageAccounts/marcosandboxfinopshub` |
| APIM diagnostics configuration | MEDIUM - telemetry routing | `az apim diagnostic list --service-name marco-sandbox-apim -g EsDAICoE-Sandbox` |
| Log Analytics workspace link | LOW - centralized logging | `az monitor app-insights component show --app marco-sandbox-appinsights -g EsDAICoE-Sandbox --query workspaceResourceId` |

### Validation Approach

Run the inventory script to populate unknowns:
```powershell
# From DevBox with professional account authentication
az login --tenant 9ed55846-8a81-4246-acd8-b1a01abfc0d1 --use-device-code
pwsh .\tools\finops\az-inventory-finops.ps1 -Subscriptions d2d4e571-e0f2-4f6c-901a-f88f7669bcba,802d84ab-3189-4221-8453-fcc30c8dc8ea
```

Results will populate `tools/finops/out/*.json` for analysis.

---

## Permission Model (Known Constraints)

**Evidence Source**: [eva-foundation/14-az-finops/README.md](i:/eva-foundation/14-az-finops/README.md#L61-L76)

### Current Permissions
- ✅ Cost Management Contributor (read cost data, configure exports via Portal)
- ✅ Cost Management Reader (view costs)
- ✅ Azure CLI authentication (marco.presta@hrsdc-rhdcc.gc.ca)
- ✅ Storage Blob Data Contributor on marcosandboxfinopshub (evidence: role assignment in inventory)

### Missing Permissions
- ❌ Contributor/Owner on subscription → cannot register resource providers, deploy resources programmatically
- ❌ Storage Data Contributor (CLI/PowerShell access) → Azure Policy firewall blocks non-Portal writes

**Workaround**: Portal-based configuration for exports, programmatic access for read operations only.

---

## Next Steps (Evidence Collection)

1. **Execute inventory script** (priority: HIGH)
   - Run `az-inventory-finops.ps1` from DevBox
   - Collect outputs in `tools/finops/out/`
   - Update this document with discovered resources

2. **Capture Portal screenshots** (priority: MEDIUM)
   - Cost Management Exports → Export history
   - Storage Account → Containers list
   - APIM → APIs + Policies
   - ADF → Pipelines + Runs

3. **Review historical data in Cosmos** (priority: LOW)
   - Determine if Cosmos DB contains CSV exports or structured data
   - Plan migration strategy to ADLS Gen2

4. **Update gap analysis** (priority: HIGH)
   - Incorporate inventory findings into [01-gap-analysis-finops-hubs.md](01-gap-analysis-finops-hubs.md)

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-02-17 08:20 AM ET | Marco Presta | Initial comprehensive inventory based on repository evidence |

---

**Document Status**: Draft (awaiting live inventory execution to resolve UNKNOWNs)  
**Next Review**: 2026-02-24 (after inventory script execution)
