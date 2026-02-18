# Azure FinOps - ESDC Cost Management

> **Last Updated**: February 17, 2026 (Phase 1 FinOps Enterprise Roadmap COMPLETE)
> **Status**: ✅ Daily exports active | ✅ Comprehensive roadmap documented | ✅ Phase 1 deployment guide ready | 📊 Evidence-based inventory complete
> **Scope**: EsDAICoESub + EsPAICoESub (ESDC Production) + 50+ EVA-JP APIs (cost attribution)
> **Tenant**: 9ed55846-8a81-4246-acd8-b1a01abfc0d1
> **User**: marco.presta@hrsdc-rhdcc.gc.ca (Cost Management Contributor + Reader)

---

## 🚀 **NEW: Phase 1 FinOps Enterprise Roadmap (February 17, 2026)**

### Comprehensive Documentation Delivered

**8 Complete Deliverables** (4,000+ lines, 1,800+ lines of embedded code):

1. **[00-current-state-inventory.md](docs/finops/00-current-state-inventory.md)** (268 lines)
   - Evidence-based snapshot of existing Azure resources
   - Verified inventory: 6 storage containers, 2 APIM APIs, 6 Event Grid topics
   - EVA-JP API context: 50+ APIs (38+ active endpoints) requiring cost attribution
   - Evidence sources: Baseline captured 2026-02-17 09:09:32 AM ET (12 JSON artifacts)

2. **[01-gap-analysis-finops-hubs.md](docs/finops/01-gap-analysis-finops-hubs.md)** (398 lines)
   - **7 Critical Gaps** identified vs Microsoft FinOps Hubs reference architecture
   - Priority matrix: P0 (ADX, ADF, APIM), P1 (Storage, Power BI), P2 (Governance)
   - 4-phase remediation sequence (9 weeks, 68 story points)
   - Cost estimate: $350/month incremental infrastructure

3. **[02-target-architecture.md](docs/finops/02-target-architecture.md)** (560 lines)
   - Mermaid architecture diagram (full data flow: Cost Management → ADLS → ADF → ADX → Power BI)
   - 7 component specifications with embedded code (900+ lines: Bicep, KQL, JSON, XML)
   - ADX schema: 3 tables (raw_costs, apim_usage, normalized_costs) + allocation function
   - APIM policy: Cost attribution headers (x-eva-costcenter, x-eva-caller-app, x-eva-environment)

4. **[03-deployment-plan.md](docs/finops/03-deployment-plan.md)** (480 lines)
   - **4 Phases, 9 Weeks**: Storage Foundation (Weeks 1-2) → Analytics (3-4) → APIM Attribution (5-7) → Governance (8-9)
   - Bicep modules for each phase (500+ lines embedded IaC)
   - Acceptance criteria per phase with validation commands
   - Rollback procedures for deployment safety

5. **[PHASE1-DEPLOYMENT-CHECKLIST.md](docs/finops/PHASE1-DEPLOYMENT-CHECKLIST.md)** (480 lines) ⭐ **NEW**
   - **6 Deployment Tasks** (13 story points): Containers → Lifecycle Policy → Migration → Export Config → Event Grid
   - Step-by-step operational guide with copy-paste ready commands
   - Embedded migration script: `migrate-costs-to-raw.ps1` (60+ lines) with dry-run mode
   - Bicep module: Storage lifecycle policy (90d Cool, 180d Archive)
   - Per-task acceptance criteria with evidence collection
   - Rollback procedures (original costs/ container preserved until validation)

6. **[04-backlog.md](docs/finops/04-backlog.md)** (340 lines)
   - **5 Epics, 68 Story Points, 9 Weeks**: Epic 1 (Foundation, 13pts) → Epic 2 (Analytics, 21pts) → Epic 3 (APIM, 13pts) → Epic 4 (Reporting, 8pts) → Epic 5 (Governance, 13pts)
   - ADO-ready work items with T-shirt sizing (XS=1pt to XL=8pt)
   - Success metrics (KPIs): Ingestion latency <30min, APIM attribution >80%, Cost accuracy ±5%

7. **[05-evidence-pack.md](docs/finops/05-evidence-pack.md)** (340 lines)
   - **9 Evidence Categories**: Storage, Event Grid, ADF, ADX, APIM, Cost Exports, RBAC, Monitoring, Summary
   - Executable validation commands (Azure CLI + KQL queries)
   - Expected outputs for audit trail

8. **[az-inventory-finops.ps1](tools/finops/az-inventory-finops.ps1)** (650 lines) ⭐ **TESTED**
   - Automated inventory collection (15+ Azure resource types across 2 subscriptions)
   - Successfully executed 2026-02-17 09:09:32 AM ET
   - Generated 12 JSON baseline artifacts (storage, APIM, Event Grid, RBAC)

**Navigation**: See **[docs/finops/README.md](docs/finops/README.md)** for complete index with reading order by role (architect, PM, engineer, QA)

**Business Value**:
- ✅ **Cost Visibility**: Centralized analytics across 2 subscriptions (EsDAICoESub + EsPAICoESub)
- ✅ **API Attribution**: Chargeback for **50+ EVA-JP APIs** (38+ active endpoints from EVA-JP-reference-0113) via APIM telemetry
- ✅ **Application Mapping**: Integration with EVA-JP comprehensive API inventory (FastAPI backend, 2144 lines)
- ✅ **Compliance**: Tag enforcement, 90%+ resource compliance target
- ✅ **Optimization**: Power BI dashboards for trend analysis, cost allocation accuracy ±5%

---

## Current Status (February 17, 2026)

### What Works

| Method | Status | Use Case | Limitation |
|--------|--------|----------|------------|
| **Azure Portal native exports** | ✅ [ACTIVE] Configured | Daily cost data to Blob storage | Manual Portal setup required |
| **Python SDK (extract_costs_sdk.py)** | ✅ [WORKS] | Ad-hoc queries <5,000 rows | Pagination broken >5,000 rows |
| **REST API via az rest** | ✅ [TESTED] | Historical backfill with pagination | Daily aggregated totals only (no resource details) |

### What Does NOT Work

| Method | Blocker | Attempted |
|--------|---------|-----------|
| **SDK pagination (>5,000 rows)** | TypeError: Session.request() got unexpected kwarg 'skip_token' (azure-mgmt-costmanagement 4.0.1, Python 3.13) | 10+ attempts with chunking strategies |
| **CLI export create (az costmanagement export)** | Extension install fails (Windows registry bug: FileNotFoundError CSIDL_COMMON_APPDATA) | 3 attempts |
| **REST API export config** | Microsoft.CostManagementExports provider not registered (needs Owner/Contributor) | 2 attempts |
| **FinOps Hub deployment** | AuthorizationFailed - no Contributor role on subscription | 2 attempts |
| **Programmatic storage access** | Azure Policy firewall (DefaultAction: Deny) blocks CLI/PowerShell | Multiple attempts |

### Active Exports

| Export | Subscription | Status | Storage | Configured Via |
|--------|-------------|--------|---------|---------------|
| EsDAICoESub-Daily | d2d4e571-e0f2-4f6c-901a-f88f7669bcba | ✅ [ACTIVE] 2 successful runs (Feb 16) | marcosandboxfinopshub/costs/EsDAICoESub/ | Azure Portal |
| EsPAICoESub-Daily | 802d84ab-3189-4221-8453-fcc30c8dc8ea | ✅ [ACTIVE] Succeeded (Feb 16, 11:36 AM) | marcosandboxfinopshub/costs/EsPAICoESub/ | Azure Portal |

---

## Subscriptions

| Subscription | ID | Resources | Daily Records | Notes |
|-------------|-----|-----------|---------------|-------|
| **EsDAICoESub** | d2d4e571-e0f2-4f6c-901a-f88f7669bcba | 1,200 resources | ~7,000+/day | Primary AI/ML (dev/stage), 21 Azure OpenAI instances |
| **EsPAICoESub** | 802d84ab-3189-4221-8453-fcc30c8dc8ea | 203 resources | ~2,500/month | Production (prd), 3 Azure OpenAI instances |

**Note**: Cost figures intentionally omitted pending comprehensive FinOps Hub deployment. Focus: **50+ EVA-JP APIs** requiring APIM cost attribution across environments.

---

## Permission Model

**What we have**:
- Cost Management Contributor (read cost data, configure exports via Portal)
- Cost Management Reader (view costs)
- Azure CLI authentication (az login --tenant 9ed55846-...)

**What we lack** (and why it matters):
- **Contributor/Owner on subscription**: Cannot register resource providers, deploy resources, or configure exports programmatically via REST API
- **Storage Data Contributor**: Cannot write to storage via CLI/SDK (Azure Policy firewall blocks non-Portal access)

**Workaround**: All configuration done via Azure Portal GUI, which bypasses both permission and firewall restrictions.

---

## Project Structure

```
14-az-finops/
  README.md                                    # This file
  requirements.txt                             # Python deps (azure-mgmt-costmanagement, pandas)
  
  docs/
    finops/                                    # ⭐ NEW: Phase 1 FinOps Enterprise Roadmap
      README.md                                # Navigation index (390 lines)
      00-current-state-inventory.md            # Evidence-based snapshot (268 lines)
      01-gap-analysis-finops-hubs.md           # 7 gaps vs Microsoft reference (398 lines)
      02-target-architecture.md                # Mermaid diagrams + code samples (560 lines)
      03-deployment-plan.md                    # 4 phases, 9 weeks, Bicep modules (480 lines)
      PHASE1-DEPLOYMENT-CHECKLIST.md           # ⭐ Operational guide (480 lines, copy-paste ready)
      04-backlog.md                            # 5 epics, 68 story points (340 lines)
      05-evidence-pack.md                      # Validation commands (340 lines)
    EXPORTATION-BEST-PRACTICES.md              # Export strategy and lessons learned
    RATE-LIMITING-BEST-PRACTICES.md            # API rate limit handling
  
  tools/
    finops/
      az-inventory-finops.ps1                  # ⭐ Automated inventory (650 lines, TESTED)
      out/                                     # Baseline artifacts (12 JSON files, 2026-02-17 09:09:32)
        storage-containers-20260217-090932.json
        apim-apis-20260217-090932.json
        eventgrid-subscriptions-20260217-090932.json
        storage-rbac-20260217-090932.json
        # ... 8 more JSON files
  
  scripts/
    extract_costs_sdk.py                       # Python SDK - ad-hoc queries (<5K rows)
    Backfill-Costs-REST.ps1                    # REST API historical backfill (1-month tested)
    migrate-costs-to-raw.ps1                   # ⭐ NEW: Export migration (in PHASE1 checklist)
    Configure-EsDAICoESub-CostExport.ps1       # Export config (blocked by provider)
    Configure-EsPAICoESub-CostExport.ps1       # Export config (blocked by provider)
    azure_inventory.py                         # Resource inventory
    offline-packages/                          # Offline .whl files for ESDC workstation
    pipelines/                                 # Data Factory pipeline definitions (JSON)
  
  infra/                                       # ⭐ NEW: Infrastructure as Code
    bicep/
      storage-lifecycle.bicep                  # Lifecycle policy (in PHASE1 checklist)
      # ... additional Bicep modules in 03-deployment-plan.md
  
  portal-exports/                              # Manual Portal downloads (Jan 27, 2026)
  output/
    historical/                                # Target for backfill output
      EsDAICoESub/                             # REST API backfill (1-month tested)
      EsPAICoESub/                             # REST API backfill (1-month tested)
  archive/
    20260216-audit-cleanup/                    # 96+ archived files from 3-week investigation
```

---

## Deployment Roadmap

### ✅ Phase 0: Data Collection Foundation (COMPLETE - Feb 16, 2026)

| Task | Status | Notes |
|------|--------|-------|
| Configure EsDAICoESub daily export (Portal) | ✅ [DONE] | Active, 2 successful runs (Feb 16) |
| Configure EsPAICoESub daily export (Portal) | ✅ [DONE] | Active, succeeded (Feb 16, 11:36 AM) |
| Test Backfill-Costs-REST.ps1 for historical data | ✅ [DONE] | 1-month test successful (January 2026) |
| Verify export data landing in Blob storage | ✅ [DONE] | Confirmed 2.3MB + 371KB exports present |
| **Capture baseline inventory** | ✅ [DONE] | 12 JSON artifacts, 2026-02-17 09:09:32 AM ET |
| **Create comprehensive roadmap** | ✅ [DONE] | 8 deliverables, 4,000+ lines, 1,800+ lines code |

---

### 🚀 Phase 1: Storage Foundation (Weeks 1-2, 13 Story Points)

**Status**: 📋 [READY TO EXECUTE] - Follow **[PHASE1-DEPLOYMENT-CHECKLIST.md](docs/finops/PHASE1-DEPLOYMENT-CHECKLIST.md)**

**6 Deployment Tasks**:

| Task | Size | Description | Evidence |
|------|------|-------------|----------|
| 1.1.1 | XS (1pt) | Create 4 storage containers (raw, processed, archive, checkpoint) | Container list, test upload |
| 1.1.2 | S (2pt) | Configure lifecycle policy (Bicep: 90d Cool, 180d Archive) | Bicep deployment, Portal screenshot |
| 1.1.3 | M (3pt) | Migrate existing exports to raw/costs/ hierarchy (PowerShell script) | Blob count comparison, sample validation |
| 1.2.1 | S (2pt) | Update Cost Management export destinations (Portal) | Export config screenshots |
| 1.3.1 | S (2pt) | Verify Event Grid system topic status | Metrics, provisioning state |
| 1.3.2 | M (3pt) | Create Event Subscription to ADF (Phase 2 dependency) | Event subscription JSON |

**Deliverables**:
- ✅ Hierarchical storage structure: `raw/costs/{SubscriptionName}/{YYYY}/{MM}/`
- ✅ Automated tiering policy (cost optimization)
- ✅ Event-driven ingestion pipeline foundation
- ✅ Data governance framework (retention policies)

**Duration**: 2 weeks (10 business days)  
**Prerequisites**: Azure CLI auth, Contributor on EsDAICoE-Sandbox, baseline inventory captured  
**Critical Safety**: Original `costs/` container preserved until validation complete

**Quick Start**:
```powershell
# Open deployment checklist
code docs\finops\PHASE1-DEPLOYMENT-CHECKLIST.md

# Follow Task 1.1.1 → Create storage containers (15 minutes)
```

---

### 📊 Phase 2: Analytics & Ingestion (Weeks 3-4, 21 Story Points)

**Status**: ⏳ [PLANNED] - See **[03-deployment-plan.md](docs/finops/03-deployment-plan.md)** → Phase 2

**Key Tasks**:
- Deploy ADX cluster (`marcofinopsadx`, Dev SKU, canadacentral)
- Create ADX schema (3 tables: raw_costs, apim_usage, normalized_costs)
- Deploy ADF pipelines (ingest-costs-to-adx, backfill-historical)
- Wire Event Grid subscription to ADF webhook
- Test ingestion: Daily exports → ADX within 30 minutes

**Dependencies**: Phase 1 complete (storage containers, Event Grid)

---

### 🎯 Phase 3: APIM Attribution & Telemetry (Weeks 5-7, 13 Story Points)

**Status**: ⏳ [PLANNED] - See **[03-deployment-plan.md](docs/finops/03-deployment-plan.md)** → Phase 3

**Key Tasks**:
- Implement APIM base policy (cost attribution headers for 50+ EVA-JP APIs)
- Configure App Insights diagnostics (100% sampling)
- Deploy telemetry ingestion pipeline (App Insights → ADX)
- Create allocation function: `AllocateCostByApp()` (KQL)
- Run 12-month backfill pipeline

**Business Value**: **50+ EVA-JP APIs** (38+ active endpoints) get granular cost visibility

**Dependencies**: Phase 2 complete (ADX cluster, ingestion pipeline)

---

### 🔒 Phase 4: Reporting & Governance (Weeks 8-9, 21 Story Points)

**Status**: ⏳ [PLANNED] - See **[03-deployment-plan.md](docs/finops/03-deployment-plan.md)** → Phase 4

**Key Tasks**:
- Deploy 3 Power BI reports (cost trend, allocation, tag compliance)
- Implement Azure Policy (tag enforcement: CostCenter required)
- Configure VNet + private endpoints (storage, ADX)
- Deploy GitHub Actions CI/CD workflow
- Final validation (all commands from 05-evidence-pack.md)

**Success Metrics**:
- Cost Data Completeness: 100% (12 months backfilled)
- Ingestion Latency: <30 minutes
- APIM Attribution Coverage: >80% requests tagged
- Tag Compliance: >90% resources
- Cost Allocation Accuracy: ±5%
- Power BI Query Performance: <3 seconds

---

### 📈 Deployment Timeline Summary

| Phase | Duration | Story Points | Status | Key Deliverable |
|-------|----------|--------------|--------|----------------|
| **Phase 0** | 3 weeks | N/A | ✅ [COMPLETE] | Daily exports + Comprehensive roadmap |
| **Phase 1** | 2 weeks | 13 | 📋 [READY] | Storage foundation + Lifecycle policy |
| **Phase 2** | 2 weeks | 21 | ⏳ [PLANNED] | ADX cluster + Ingestion pipelines |
| **Phase 3** | 3 weeks | 13 | ⏳ [PLANNED] | APIM attribution (50+ APIs) |
| **Phase 4** | 2 weeks | 21 | ⏳ [PLANNED] | Power BI + Governance |
| **TOTAL** | **9 weeks** | **68 points** | **15 story points/sprint** | Enterprise FinOps capability |

---

## Quick Start

### Ad-Hoc Cost Query (Small Date Ranges)

```powershell
# Authenticate
az login --tenant 9ed55846-8a81-4246-acd8-b1a01abfc0d1

# Query costs for a few days (SDK works for <5000 rows)
python scripts/extract_costs_sdk.py --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba --start-date 2026-02-10 --end-date 2026-02-16
```

### Configure Daily Export (Portal)

1. Go to Azure Portal > Cost Management > Exports
2. Select subscription scope
3. Create new export: Type=ActualCost, Schedule=Daily, Format=CSV
4. Storage: marcosandboxfinopshub, container=costs, directory={SubscriptionName}
5. Set date range and save

### Historical Backfill (REST API)

```powershell
# Test with 1 month
.\scripts\Backfill-Costs-REST.ps1 -MonthsToBackfill 1

# Full 12 months
.\scripts\Backfill-Costs-REST.ps1 -MonthsToBackfill 12
```

---

## Lessons Learned (Audit Summary)

This project went through 10 extraction attempts over 3 weeks (Jan 27 - Feb 16, 2026) cycling between SDK, CLI, REST API, and Portal before identifying two fundamental blockers:

1. **Python SDK pagination is broken**: azure-mgmt-costmanagement 4.0.1 on Python 3.13 throws `TypeError: Session.request() got an unexpected keyword argument 'skip_token'` after page 1-2. All chunking strategies (monthly, weekly, 10-day, daily) still hit this ceiling at 5,000-10,000 rows. The `data/historical/` files that appeared complete were silently truncated at exactly 5,001 rows (1 header + 5,000 data = single page).

2. **No Contributor permissions**: Cannot register resource providers, deploy infrastructure, or configure exports programmatically. Azure Policy firewall blocks CLI/PowerShell storage access.

**What actually works**: Azure Portal for export configuration (bypasses both blockers), and `az rest` for direct REST API calls with manual nextLink pagination.

### Extraction Attempt Timeline

| # | Date | Method | Result | Blocker |
|---|------|--------|--------|---------|
| 1 | Jan 27 | Manual Portal download | Partial success | Manual, not automated |
| 2 | Jan 29 | FinOps Toolkit (Deploy-FinOpsHub) | Failed | Region restrictions + no permissions |
| 3 | Jan 30 | CLI (az costmanagement export create) | Failed | Extension install fails (Windows) |
| 4 | Jan 31 | REST API export config | Failed | CostManagementExports provider not registered |
| 5 | Feb 1 | Python SDK (small query) | Success (28 rows) | Worked but only because <5,000 rows |
| 6 | Feb 6 | SDK 12-month extraction | Silently truncated | All 11 CSVs capped at 5,001 rows |
| 7 | Feb 10 | Deploy-ESDC-FinOps.ps1 | Failed | AuthorizationFailed (no Contributor) |
| 8 | Feb 15 | Scope change + deploy retry | Failed | Same permission blocker |
| 9 | Feb 16 | SDK weekly/10-day chunking | Still truncated | SDK pagination broken regardless of chunk size |
| 10 | Feb 16 | Portal native export config | **Success** | Bypasses all blockers |

See `archive/20260216-audit-cleanup/` for the full history of attempts (96+ archived files).

---

## 📚 Documentation Quick Links

### For Implementation Teams
- **Start Here**: [docs/finops/README.md](docs/finops/README.md) - Master index with reading order by role
- **Deploy Phase 1**: [PHASE1-DEPLOYMENT-CHECKLIST.md](docs/finops/PHASE1-DEPLOYMENT-CHECKLIST.md) - Step-by-step operational guide
- **Understand Gaps**: [01-gap-analysis-finops-hubs.md](docs/finops/01-gap-analysis-finops-hubs.md) - 7 critical gaps vs Microsoft reference
- **Architecture**: [02-target-architecture.md](docs/finops/02-target-architecture.md) - Mermaid diagrams + code samples
- **Sprint Planning**: [04-backlog.md](docs/finops/04-backlog.md) - 5 epics, 68 story points, ADO-ready
- **Validation**: [05-evidence-pack.md](docs/finops/05-evidence-pack.md) - Executable commands for audit

### For Executives
- **Executive Summary**: [docs/finops/README.md](docs/finops/README.md) → Business Value section
- **Investment**: $350/month incremental (ADX Dev SKU + storage/networking)
- **Timeline**: 9 weeks (4.5 sprints at 15 points/sprint)
- **ROI**: Cost visibility for 1,403 resources + 50+ EVA-JP APIs, tag compliance >90%, chargeback capability

### For Auditors
- **Evidence Baseline**: [tools/finops/out/](tools/finops/out/) - 12 JSON artifacts (2026-02-17 09:09:32 AM ET)
- **Validation Commands**: [05-evidence-pack.md](docs/finops/05-evidence-pack.md) - 9 evidence categories
- **Inventory Script**: [az-inventory-finops.ps1](tools/finops/az-inventory-finops.ps1) - Automated capture
- **Current State**: [00-current-state-inventory.md](docs/finops/00-current-state-inventory.md) - Evidence-based assessment

---

**Project Owner**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Last Updated**: February 17, 2026 08:20 AM ET  
**Phase 1 Status**: ✅ Documentation Complete | 📋 Ready for Deployment Execution
