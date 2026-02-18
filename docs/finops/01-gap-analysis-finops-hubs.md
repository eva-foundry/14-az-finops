# 01 - Gap Analysis: marcosandbox vs FinOps Hubs Reference

**Document Type**: Architecture  
**Phase**: Assessment  
**Audience**: [architects, finops-analysts, engineers]  
**Last Updated**: 2026-02-17 08:20 AM ET  
**Author**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Reference**: [Microsoft FinOps Toolkit](https://aka.ms/finops/toolkit)

---

## Overview

This document compares the current marcosandbox FinOps infrastructure against the Microsoft FinOps Hubs reference architecture to identify gaps and prioritize remediation efforts. The FinOps Hubs pattern provides enterprise-grade cost management with centralized data ingestion, normalization, allocation, and reporting.

**Gap Summary**: 7 critical components identified, 3 present, 4 missing or partial.

---

## FinOps Hubs Reference Architecture (Minimum Components)

### Tier 1: Data Collection & Landing
- **ADLS Gen2 Storage** with hierarchical namespace
  - Container: `raw/` (landing zone for exports)
  - Container: `processed/` (normalized/enriched data)
  - Container: `archive/` (long-term retention)
- **Event Grid** integration (Storage → trigger ingestion)
- **Cost Management Exports** (daily/monthly, ActualCost + Amortized)

### Tier 2: Ingestion & Transformation
- **Azure Data Factory** (or Synapse/Fabric) pipelines
  - Copy activity: Export CSV → Raw storage
  - Data flow: Normalize, enrich, tag parsing
- **Azure Data Explorer (ADX)** cluster + database
  - Table: `raw_costs` (direct CSV ingestion)
  - Table: `normalized_costs` (cleansed, typed columns)
  - Table: `apim_usage` (for attribution)
- **Ingestion Mappings** (CSV → ADX schema)

### Tier 3: Attribution & Allocation
- **APIM Integration** (telemetry with custom headers)
  - Policy: Inject `x-costcenter`, `x-caller-app`, `x-environment`
  - Diagnostics: Forward to Log Analytics/App Insights
- **ADX Allocation Views** (KQL functions)
  - Join cost data with usage telemetry by timestamp/resource
  - Allocate spend to consuming applications/cost centers

### Tier 4: Reporting & Governance
- **Power BI Workspace** with KQL direct query
  - Template: Cost trends, resource group breakdown, tag compliance
- **Azure Policy** enforcement
  - Require tags: `CostCenter`, `Application`, `Environment`
  - Enforce export configuration at subscription level
- **RBAC/Private Endpoints** (enterprise security)
  - Managed identities with least-privilege roles
  - Private endpoints for storage, ADX, ADF

---

## Current State Mapping (Evidence-Based)

### ✅ Components Present

| Component | Status | Evidence | Notes |
|-----------|--------|----------|-------|
| **ADLS Gen2 Storage** | ✅ Present | [MARCO-INVENTORY L107](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L107) | marcosandboxfinopshub (StorageV2, dfs endpoint enabled) |
| **Event Grid systemTopic** | ✅ Present | [MARCO-INVENTORY L157](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L157) | marcosandboxfinopshub-52dd1c15... configured |
| **Cost Exports (Active)** | ✅ Active | [14-az-finops README L35-36](i:/eva-foundation/14-az-finops/README.md#L35-L36) | Daily exports for both subscriptions (Feb 16, 2026) |
| **Data Factory** | ⚠️ Partial | [MARCO-INVENTORY L145](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L145) | marco-sandbox-finops-adf exists, pipelines UNKNOWN |
| **APIM** | ⚠️ Partial | [MARCO-INVENTORY L136](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L136) | marco-sandbox-apim exists, policies UNKNOWN |
| **App Insights** | ✅ Present | [MARCO-INVENTORY L137](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L137) | marco-sandbox-appinsights configured |

### ❌ Components Missing

| Component | Status | Impact | Priority |
|-----------|--------|--------|----------|
| **ADX Cluster + Database** | ❌ Missing | Cannot perform analytics, KQL queries, or Power BI integration | CRITICAL |
| **Storage Container Structure** | ⚠️ Incomplete | Only `costs/` present, need `raw/`, `processed/`, `archive/` | HIGH |
| **ADF Ingestion Pipelines** | ❌ Unknown/Missing | No automated CSV → ADX ingestion | CRITICAL |
| **APIM Attribution Policies** | ❌ Unknown | No cost allocation by caller/app | CRITICAL |
| **ADX Ingestion Mappings** | ❌ Missing | Cannot ingest cost CSV into ADX tables | CRITICAL |
| **Power BI Integration** | ❌ Missing | No reporting capability | HIGH |
| **Azure Policy (Tags)** | ❌ Missing | No tag enforcement | MEDIUM |
| **Private Endpoints** | ⚠️ Unknown | Network security posture unclear | MEDIUM |

---

## Detailed Gap Analysis

### Gap 1: Azure Data Explorer (ADX) Cluster [CRITICAL]

**Current State**: No ADX cluster found in inventory snapshot.

**Evidence**: [MARCO-INVENTORY](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md) lists 24 marco-sandbox resources; no ADX/Kusto resources present.

**Impact**:
- Cannot perform large-scale cost analytics (CSV exports not queryable at scale)
- Power BI cannot use KQL direct query (forced to import mode with refresh limits)
- No near-real-time allocation views (joins must be done in Power BI desktop)

**Recommended Action**:
- Deploy ADX cluster in canadacentral (Dev SKU: 2 nodes, Engine D11_v2 ~$300/month)
- Create database `finopsdb` with tables: `raw_costs`, `normalized_costs`, `apim_usage`
- Configure ingestion endpoint and managed identity

**Acceptance Criteria**:
- ADX cluster provisioned and query endpoint accessible
- Database and schema created via IaC (Bicep/Terraform)
- Sample CSV ingested successfully and KQL query returns results

---

### Gap 2: Storage Container Hierarchy [HIGH]

**Current State**: Single container `costs/` with subscription subdirectories.

**Evidence**: Export paths documented in [14-az-finops README](i:/eva-foundation/14-az-finops/README.md#L167): `marcosandboxfinopshub, container=costs, directory={SubscriptionName}`

**Impact**:
- No separation between raw landing zone and processed data
- Cannot implement lifecycle policies per processing stage
- Difficult to track data lineage (raw → processed → aggregated)

**Recommended Structure**:
```
marcosandboxfinopshub/
├── raw/costs/{subscription}/{YYYY}/{MM}/         # Landing zone for exports
├── processed/costs/{subscription}/{YYYY}/{MM}/   # Normalized, enriched CSVs
├── archive/costs/{subscription}/{YYYY}/          # Archived after ADX ingestion
└── checkpoint/                                   # ADF pipeline state/manifest
```

**Acceptance Criteria**:
- Containers created and accessible via `az storage container list`
- Lifecycle policy configured: move to Cool after 90 days, Archive after 180 days
- ADF pipeline writes manifest to `checkpoint/` after successful ingestion

---

### Gap 3: ADF Ingestion Pipelines [CRITICAL]

**Current State**: ADF factory `marco-sandbox-finops-adf` exists but pipeline configuration unknown.

**Evidence**: [MARCO-INVENTORY L145](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L145)

**Impact**:
- No automated ingestion from Blob → ADX
- Manual effort required to download and process exports
- Event Grid triggers have no consumer (wasted events)

**Required Pipelines**:

| Pipeline Name | Trigger | Activities | Output |
|---------------|---------|------------|--------|
| `ingest-costs-to-adx` | Event Grid (blob created) | 1. Decompress CSV<br>2. Validate schema<br>3. ADX copy activity<br>4. Move to processed/ | ADX table populated |
| `backfill-historical` | Manual/Scheduled | 1. List blobs in raw/<br>2. Iterate and ingest<br>3. Track progress in checkpoint/ | Historical data in ADX |
| `enrich-and-normalize` | Scheduled (daily 2 AM) | 1. Read processed/<br>2. Parse tags<br>3. Apply enrichment rules<br>4. Write to normalized_costs | Enriched dataset |

**Acceptance Criteria**:
- Pipelines deployed via IaC (ARM template in repo)
- Test execution with sample CSV successful
- Monitoring alerts configured for pipeline failures

---

### Gap 4: APIM Cost Attribution [CRITICAL]

**Current State**: APIM resource `marco-sandbox-apim` exists with 2 deployed APIs (echo-api, eva-jp-query-api at path `/eva-jp/v1`), but comprehensive policy configuration for cost attribution headers is UNKNOWN. An **EVA-JP API Inventory Project** is underway to catalog and attribute **50+ APIs** (38+ active endpoints confirmed) from `I:\EVA-JP-reference-0113\app\backend\`.

**Evidence**: 
- [MARCO-INVENTORY L136](i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md#L136)
- Inventory baseline (2026-02-17 09:09:32): 2 APIs deployed (echo-api, eva-jp-query-api)
- EVA-JP Backend: 38+ active endpoints (33 @app.get/post/put/delete + 5 @router endpoints in sessions.py)
- Source: `I:\EVA-JP-reference-0113\app\backend\app.py` (FastAPI application, 2144 lines)

**Impact**:
- No ability to allocate Azure spend to consuming applications
- Cannot implement showback/chargeback to internal teams (50+ APIs require cost visibility)
- Usage telemetry not correlated with cost data
- **50+ EVA-JP APIs** lack granular cost attribution across environments (dev/test/production)

**Required Implementation**:

**APIM Policy Snippet** (inbound):
```xml
<policies>
    <inbound>
        <!-- Extract cost center from JWT claim or header -->
        <set-variable name="costCenter" value="@(context.Request.Headers.GetValueOrDefault("x-costcenter", "UNKNOWN"))" />
        <set-variable name="callerApp" value="@(context.Request.Headers.GetValueOrDefault("x-caller-app", context.Request.Headers.GetValueOrDefault("x-client-id", "UNKNOWN")))" />
        <set-variable name="environment" value="@(context.Request.Headers.GetValueOrDefault("x-environment", "production"))" />
        
        <!-- Add to App Insights custom dimensions -->
        <set-header name="x-eva-costcenter" exists-action="override">
            <value>@((string)context.Variables["costCenter"])</value>
        </set-header>
        <set-header name="x-eva-caller-app" exists-action="override">
            <value>@((string)context.Variables["callerApp"])</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
```

**Diagnostic Configuration**:
- Enable diagnostics for **all APIs** (50+ EVA-JP APIs from inventory project) → App Insights `marco-sandbox-appinsights`
- Include custom dimensions (headers) in telemetry
- Configure sampling (100% for cost attribution accuracy)
- **EVA-JP API Catalog Integration**: Map 38+ active endpoints to cost center tags

**Acceptance Criteria**:
- Policy applied to all APIs (or base policy covering 50+ APIs)
- Test request shows custom dimensions in App Insights logs
- ADX ingestion pipeline extracts headers from telemetry
- **80%+ of EVA-JP API requests** have cost center attribution (per KPI in 04-backlog.md)

---

### Gap 5: ADX Ingestion Mappings [CRITICAL]

**Current State**: No ADX cluster means no ingestion mappings.

**Required Schema** (Cost CSV → ADX):

```kusto
.create table raw_costs (
    BillingAccountId: string,
    BillingAccountName: string,
    BillingPeriodStartDate: datetime,
    BillingPeriodEndDate: datetime,
    BillingProfileId: string,
    BillingProfileName: string,
    AccountOwnerId: string,
    AccountOwnerName: string,
    SubscriptionId: string,
    SubscriptionName: string,
    ResourceGroup: string,
    ResourceLocation: string,
    Date: datetime,
    ProductName: string,
    MeterCategory: string,
    MeterSubCategory: string,
    MeterId: string,
    MeterName: string,
    MeterRegion: string,
    UnitOfMeasure: string,
    Quantity: real,
    EffectivePrice: real,
    CostInBillingCurrency: real,
    CostCenter: string,
    ConsumedService: string,
    ResourceId: string,
    Tags: dynamic,
    OfferId: string,
    IsAzureCreditEligible: string,
    PartNumber: string,
    PayGPrice: real,
    PricingModel: string,
    ResourceName: string,
    ServiceFamily: string,
    UnitPrice: real,
    // Additional columns as needed
    IngestionTime: datetime
)

.create table raw_costs ingestion csv mapping 'CostExportMapping'
'['
'{"column":"Date","DataType":"datetime","Properties":{"Ordinal":"0"}},'
'{"column":"SubscriptionName","DataType":"string","Properties":{"Ordinal":"1"}},'
'{"column":"ResourceGroup","DataType":"string","Properties":{"Ordinal":"2"}},'
// ... (continue for all 55+ columns)
']'
```

**Acceptance Criteria**:
- Schema created in ADX database
- CSV ingestion mapping tested with sample export
- Data types validated (no conversion errors)

---

### Gap 6: Power BI Integration [HIGH]

**Current State**: No Power BI workspace or reports configured.

**Required Components**:
- Power BI workspace (shared capacity or Premium)
- ADX connection (KQL direct query, not import mode)
- Report templates:
  1. **Cost Trend Dashboard** (daily/weekly/monthly aggregates)
  2. **Resource Group Breakdown** (top 10 by spend)
  3. **Tag Compliance Report** (untagged resources, missing cost center)
  4. **APIM Allocation Report** (spend by caller app/cost center)

**Acceptance Criteria**:
- Workspace created and access granted to FinOps team
- Sample PBIX connected to ADX and renders data
- Scheduled refresh configured (if using import mode for aggregates)

---

### Gap 7: Governance (Policies & RBAC) [MEDIUM]

**Current State**: Tags present on marco-sandbox resources but enforcement unknown.

**Required Azure Policies**:

| Policy | Effect | Scope | Parameters |
|--------|--------|-------|------------|
| Require CostCenter tag | Deny | Subscription | List of resource types |
| Require Environment tag | Audit | Subscription | Valid values: dev,stage,prod |
| Enforce Cost Export | DeployIfNotExists | Subscription | Export to marcosandboxfinopshub |
| Restrict Storage Firewall | Deny | Sandbox RG | Allow only VNet/Private Endpoints |

**RBAC Requirements** (Managed Identities):

| Identity | Scope | Role | Purpose |
|----------|-------|------|---------|
| `mi-finops-adf` | marcosandboxfinopshub | Storage Blob Data Contributor | Read exports, write processed |
| `mi-finops-adf` | marco-finops-adx | Database Ingestor | Ingest to ADX tables |
| `mi-finops-powerbi` | marco-finops-adx | Database Viewer | Power BI query access |

**Acceptance Criteria**:
- Policies assigned and compliance dashboard shows results
- Managed identities created and role assignments validated
- Test: Create resource without CostCenter tag → denied

---

## Priority Matrix

| Gap | Impact | Effort | Priority | Start Phase |
|-----|--------|--------|----------|-------------|
| ADX Cluster | CRITICAL | HIGH | 🔴 P0 | Phase 2 |
| ADF Pipelines | CRITICAL | HIGH | 🔴 P0 | Phase 2 |
| APIM Attribution | CRITICAL | MEDIUM | 🔴 P0 | Phase 3 |
| Ingestion Mappings | CRITICAL | MEDIUM | 🔴 P0 | Phase 2 |
| Storage Hierarchy | HIGH | LOW | 🟡 P1 | Phase 1 |
| Power BI | HIGH | MEDIUM | 🟡 P1 | Phase 3 |
| Governance | MEDIUM | MEDIUM | 🟢 P2 | Phase 4 |

---

## Recommended Remediation Sequence

### Phase 1: Foundation (Weeks 1-2)
- Create storage container structure (`raw/`, `processed/`, `archive/`)
- Configure Event Grid subscription to ADF (if not present)
- Validate current exports landing correctly

### Phase 2: Analytics Infrastructure (Weeks 3-4)
- Deploy ADX cluster + database
- Create ingestion mappings and schema
- Deploy ADF pipelines for ingestion
- Test end-to-end: Export → Blob → ADF → ADX

### Phase 3: Attribution & Reports (Weeks 5-7)
- Implement APIM attribution policies and diagnostics
- Create ADX telemetry ingestion pipeline
- Backfill historical cost data (12 months)
- Deploy Power BI reports

### Phase 4: Hardening (Weeks 8-9)
- Deploy Azure Policies for tag enforcement
- Enable private endpoints for storage and ADX
- Implement CI/CD for IaC modules
- Conduct security review

---

## Cost Estimate (Incremental Monthly)

| Resource | SKU/Config | Monthly Cost (CAD) |
|----------|------------|-------------------|
| ADX Cluster | Dev (2 nodes D11_v2) | ~$300 |
| ADF | ~10 pipeline runs/day | ~$20 |
| Storage (additional) | Processed/Archive containers | ~$10 |
| Power BI | Shared workspace (existing) | $0 |
| **Total Incremental** | | **~$330/month** |

**ROI**: With $297K/month combined spend, even 0.5% optimization (~$1,485/month) pays for infrastructure 4.5x over.

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-02-17 08:20 AM ET | Marco Presta | Initial gap analysis with evidence mapping and remediation plan |

---

**Document Status**: Draft (pending inventory script execution for UNKNOWN validation)  
**Next Review**: 2026-02-24 (after Phase 1 completion)
