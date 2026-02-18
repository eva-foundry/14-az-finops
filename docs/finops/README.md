# FinOps Enterprise Roadmap - Documentation Index

**Project**: Marcosandbox FinOps Hub Implementation  
**Location**: `i:/eva-foundation/14-az-finops/docs/finops/`  
**Date**: 2026-02-17 08:20 AM ET  
**Author**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Status**: Ready for Implementation

---

## Executive Summary

This directory contains the **complete evidence-based FinOps roadmap** for deploying Microsoft FinOps Hubs with APIM cost attribution in the marcosandbox (EsDAICoE-Sandbox) Azure environment.

**Key Deliverables**:
- ✅ Current state inventory with evidence links
- ✅ Gap analysis against FinOps Hubs reference architecture
- ✅ Target architecture with Mermaid diagrams and technical specs
- ✅ Phased deployment plan with Bicep IaC modules
- ✅ ADO-ready backlog (68 story points, 9 weeks)
- ✅ Evidence pack with executable validation commands
- ✅ Automated inventory script (PowerShell)

**Business Value**:
- **Cost Visibility**: Centralized analytics across EsDAICoESub + EsPAICoESub subscriptions
- **API Attribution**: Chargeback for 50+ EVA-JP APIs (38+ active, expanding) via APIM telemetry
- **Application Mapping**: Integration with EVA-JP-reference-0113 comprehensive API inventory
- **Compliance**: Tag enforcement to eliminate cost allocation gaps
- **Optimization**: Power BI dashboards for trend analysis and anomaly detection

---

## Document Navigation

### 📊 Phase 1: Discovery & Assessment

#### [00-current-state-inventory.md](./00-current-state-inventory.md)
**Purpose**: Evidence-based snapshot of existing Azure resources  
**Audience**: Engineers, Architects, Auditors  
**Key Content**:
- Executive summary (7 infrastructure components)
- Storage: `marcosandboxfinopshub` with daily exports from 2 subscriptions
- Event Grid: System topic `marcosandboxfinopshub-52dd...` active
- ADF: `marco-sandbox-finops-adf` exists (pipeline status UNKNOWN)
- APIM: `marco-sandbox-apim` (policy configuration UNKNOWN)
- **UNKNOWNs**: ADX cluster status, ingestion pipeline configuration, APIM attribution headers

**Evidence Sources**:
- `i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md`
- `i:/eva-foundation/14-az-finops/README.md`
- PowerShell scripts in `i:/eva-foundation/14-az-finops/scripts/`

**When to Use**: Starting point for any work; reference for current resource names

---

#### [01-gap-analysis-finops-hubs.md](./01-gap-analysis-finops-hubs.md)
**Purpose**: Compare current state to Microsoft FinOps Hubs reference architecture  
**Audience**: Project Managers, Cloud Architects  
**Key Content**:
- FinOps Hubs 4-tier model (Storage, Ingestion, Analytics, Reporting)
- **7 Critical Gaps**:
  1. ADX Cluster (CRITICAL - no analytics engine)
  2. Storage Hierarchy (HIGH - need raw/processed/archive containers)
  3. ADF Pipelines (CRITICAL - no automated ingestion)
  4. APIM Attribution (CRITICAL - no cost allocation headers)
  5. Ingestion Mappings (HIGH - ADX schema undefined)
  6. Power BI Reports (MEDIUM - no self-service dashboards)
  7. Governance (LOW - no tag enforcement)
- Priority matrix: P0 (ADX, ADF, APIM), P1 (Storage, Power BI), P2 (Governance)
- 4-phase remediation sequence (9 weeks)
- Cost estimate: $330/month incremental

**When to Use**: Prioritization decisions, budget justification, stakeholder briefings

---

### 🎯 Phase 2: Solution Design

#### [02-target-architecture.md](./02-target-architecture.md)
**Purpose**: Detailed technical blueprint with code samples  
**Audience**: Developers, Data Engineers, Cloud Architects  
**Key Content**:
- **Mermaid Architecture Diagram**: Full data flow (Cost Management → ADLS → Event Grid → ADF → ADX → Power BI)
- Component specifications:
  1. ADLS Gen2: Container hierarchy, lifecycle policy Bicep
  2. Event Grid: System topic + ADF webhook subscription
  3. ADF Pipelines: `ingest-costs-to-adx` (JSON definition), `backfill-historical` (parallel processing)
  4. ADX Cluster: Dev SKU, `finopsdb` database, 900+ lines of KQL schema (raw_costs, apim_usage, normalized_costs)
  5. APIM Policies: XML snippet for `x-eva-costcenter` header injection
  6. App Insights: Telemetry collection for APIM requests
  7. Power BI: 3 reports (cost trend, allocation, tag compliance)
- Security architecture: RBAC matrix, private endpoints, managed identities
- Data lineage tracking: Blob metadata → ADX `IngestionTime` column

**Embedded Code**:
- Bicep: Storage lifecycle policy, ADX cluster, managed identity
- KQL: Table schemas, materialized view, allocation function
- JSON: ADF pipeline definitions, datasets, linked services
- XML: APIM inbound policy for cost attribution
- KQL: Power BI queries

**When to Use**: Implementation reference, code reviews, architecture validation

---

### 🚀 Phase 3: Execution Planning

#### [03-deployment-plan.md](./03-deployment-plan.md)
**Purpose**: Phased IaC-first deployment with acceptance criteria  
**Audience**: DevOps Engineers, Cloud Architects, Project Managers  
**Key Content**:
- Resource naming conventions (marcofinops* prefix, canadacentral region)
- **Phase 1 (Weeks 1-2)**: Storage Foundation
  - Tasks: Create containers, lifecycle policy, migrate exports
  - Deliverables: 4 containers (raw, processed, archive, checkpoint), 90-day tiering policy
  - Acceptance: Manual CSV upload succeeds, Event Grid fires on blob creation
- **Phase 2 (Weeks 3-4)**: Analytics & Ingestion
  - Tasks: Deploy ADX cluster, create schema, ADF pipelines
  - Deliverables: `marcofinopsadx` Dev SKU, `finopsdb` with 3 tables, `ingest-costs-to-adx` pipeline
  - Acceptance: Daily exports land in ADX within 30 minutes, row counts match CSVs
- **Phase 3 (Weeks 5-7)**: APIM Attribution
  - Tasks: Implement APIM policies, App Insights integration, telemetry ingestion
  - Deliverables: APIM base policy with cost headers, `AllocateCostByApp()` KQL function, 12-month backfill
  - Acceptance: 80%+ requests have CostCenter dimension, allocated cost ±5% of invoice
- **Phase 4 (Weeks 8-9)**: Governance & Hardening
  - Tasks: Azure Policy for tags, private endpoints, CI/CD
  - Deliverables: Tag compliance policy, VNet + private endpoints for storage/ADX, GitHub Actions workflow
  - Acceptance: Resource creation blocked without CostCenter tag, public access disabled
- Rollback procedures for each phase
- Cost summary: $350/month total infrastructure cost

**Embedded Code**:
- Bicep: Complete modules for each phase (500+ lines)
- KQL: ADX schema creation scripts
- JSON: ADF pipeline definitions
- YAML: GitHub Actions workflow for CI/CD

**When to Use**: Sprint planning, Bicep module implementation, deployment execution

---

#### [PHASE1-DEPLOYMENT-CHECKLIST.md](./PHASE1-DEPLOYMENT-CHECKLIST.md)
**Purpose**: Step-by-step operational checklist for Phase 1 deployment (Storage Foundation)  
**Audience**: DevOps Engineers, Cloud Engineers, Implementation Teams  
**Key Content**:
- **Pre-Deployment Checklist**: Authentication, permissions, baseline verification (completed 2026-02-17 09:09 AM ET)
- **6 Deployment Tasks** (13 story points total):
  - Task 1.1.1: Create storage containers (raw, processed, archive, checkpoint) - XS=1pt
  - Task 1.1.2: Configure lifecycle policy (Bicep deployment with 90d/180d tiering) - S=2pt
  - Task 1.1.3: Migrate existing exports to raw/ hierarchy (PowerShell script with dry-run) - M=3pt
  - Task 1.2.1: Update Cost Management export destinations (Portal configuration) - S=2pt
  - Task 1.3.1: Verify Event Grid system topic (metrics, provisioning state) - S=2pt
  - Task 1.3.2: Create Event Subscription to ADF (Phase 2 dependency, preparation only) - M=3pt
- **Embedded Code**: 
  - PowerShell migration script `migrate-costs-to-raw.ps1` (60+ lines with dry-run support)
  - Bicep lifecycle policy module (complete, ready to deploy)
  - Azure CLI commands (copy-paste ready with validation)
  - Bash Event Grid subscription script (Phase 2 execution)
- **Acceptance Criteria**: Per-task validation checklist with expected outputs
- **Evidence Collection**: Commands to save JSON artifacts + screenshots after each task
- **Rollback Procedures**: Safe recovery steps (no data loss, original containers preserved)
- **Phase 1 Completion Checklist**: Technical validation + evidence artifacts + documentation updates

**Timeline**: 2 weeks (10 business days)  
**Prerequisites**: Azure CLI, Contributor on EsDAICoE-Sandbox, baseline captured  
**Critical Safety**: Original `costs/` container preserved until Phase 1 validation complete

**When to Use**: Execute Phase 1 deployment, validate storage foundation, collect evidence for Phase 2 planning

---

#### [04-backlog.md](./04-backlog.md)
**Purpose**: ADO-ready backlog with epics, features, and tasks  
**Audience**: Scrum Masters, Product Owners, Engineers  
**Key Content**:
- **5 Epics, 68 Story Points, 9 Weeks**
  - Epic 1: FinOps Hubs Foundation (13 points, Sprints 1-2)
  - Epic 2: Analytics & Ingestion (21 points, Sprints 3-4)
  - Epic 3: APIM Attribution & Telemetry (13 points, Sprints 5-6)
  - Epic 4: Reporting & Visualization (8 points, Sprint 7)
  - Epic 5: Governance & Hardening (13 points, Sprints 8-9)
- Task breakdown with acceptance criteria:
  - Example: "Task 2.1.2: Create ADX Schema and Tables (L=5 points)"
    - AC: `.show tables` returns 2 rows (raw_costs, apim_usage)
    - AC: Materialized view `normalized_costs` exists
    - AC: Function `AllocateCostByApp` deployed
- T-shirt sizing: XS=1pt, S=2pt, M=3pt, L=5pt, XL=8pt
- Sprint planning matrix: Velocity assumption 15 points/sprint

**Success Metrics (KPIs)**:
- Cost Data Completeness: 100% (12 months backfilled)
- Ingestion Latency: <30 minutes
- APIM Attribution Coverage: >80% requests tagged
- Tag Compliance: >90% resources
- Cost Allocation Accuracy: ±5%
- Power BI Query Performance: <3 seconds

**When to Use**: Sprint planning, work item creation in Azure DevOps, resource allocation

---

### ✅ Phase 4: Validation & Evidence

#### [05-evidence-pack.md](./05-evidence-pack.md)
**Purpose**: Executable commands for validation and audit artifacts  
**Audience**: Engineers, QA, Auditors, Compliance Officers  
**Key Content**:
- **9 Evidence Categories**:
  1. Storage (accounts, containers, network rules)
  2. Event Grid (system topics, subscriptions, metrics)
  3. Azure Data Factory (factories, pipelines, triggers, run history)
  4. Azure Data Explorer (clusters, databases, KQL validation queries)
  5. APIM (instances, APIs, base policy XML, loggers)
  6. Cost Management Exports (configuration, run history)
  7. RBAC (role assignments on storage, ADX principals, user permissions)
  8. Monitoring (App Insights, telemetry queries)
  9. Summary checklist
- Copy-paste Azure CLI commands with expected outputs
- Manual validation steps (screenshots, policy exports)
- Validation points for each command (checklist items)

**Output Artifacts**: All JSON files saved to `i:/eva-foundation/14-az-finops/tools/finops/out/`

**KQL Queries** (ADX validation):
- `.show tables` → Verify raw_costs, apim_usage
- `.show materialized-views` → Verify normalized_costs
- `raw_costs | summarize count() by Date` → Daily row counts
- `normalized_costs | where Date >= ago(30d) | summarize DailyCost=sum(Cost)` → Cost trends

**When to Use**:
- After each deployment phase (validation)
- For audit/compliance evidence collection
- To generate baseline snapshots for comparison
- Before making infrastructure changes (pre-state capture)

---

### 🤖 Automation Scripts

#### [../tools/finops/az-inventory-finops.ps1](../../tools/finops/az-inventory-finops.ps1)
**Purpose**: Automated inventory collection for evidence gathering  
**Language**: PowerShell 5.1+  
**Duration**: 2-3 minutes  
**Key Features**:
- Collects 15+ Azure resource types across 2 subscriptions
- Outputs JSON files with timestamps
- ASCII-only output (enterprise Windows safe)
- Error handling with continue-on-failure
- Skip flags for undeployed resources (`-SkipADX`)

**Usage**:
```powershell
# Full inventory
cd i:/eva-foundation/14-az-finops/tools/finops
.\az-inventory-finops.ps1

# Skip ADX (pre-deployment)
.\az-inventory-finops.ps1 -SkipADX

# Output: 15+ JSON files in ./out/ directory
```

**Output Files**:
- `storage-accounts-{timestamp}.json`
- `storage-containers-{timestamp}.json`
- `eventgrid-system-topics-{timestamp}.json`
- `adf-factories-{timestamp}.json`, `adf-pipelines-{timestamp}.json`, `adf-triggers-{timestamp}.json`
- `adx-clusters-{timestamp}.json`, `adx-databases-{timestamp}.json`
- `apim-instances-{timestamp}.json`, `apim-apis-{timestamp}.json`, `apim-loggers-{timestamp}.json`
- `cost-exports-{subId}-{timestamp}.json`
- `appinsights-{timestamp}.json`
- `storage-rbac-{timestamp}.json`

**When to Use**:
- Before deployment (baseline inventory)
- After deployment (validation)
- For comparison over time (drift detection)
- As evidence for audits

---

## Reading Order by Role

### Cloud Architect
1. **Start**: [00-current-state-inventory.md](./00-current-state-inventory.md) (understand existing)
2. **Next**: [01-gap-analysis-finops-hubs.md](./01-gap-analysis-finops-hubs.md) (identify gaps)
3. **Design**: [02-target-architecture.md](./02-target-architecture.md) (solution design)
4. **Plan**: [03-deployment-plan.md](./03-deployment-plan.md) (phased approach)

### Project Manager / Scrum Master
1. **Start**: [01-gap-analysis-finops-hubs.md](./01-gap-analysis-finops-hubs.md) (priority matrix)
2. **Backlog**: [04-backlog.md](./04-backlog.md) (sprint planning)
3. **Timeline**: [03-deployment-plan.md](./03-deployment-plan.md) (9-week roadmap)

### DevOps Engineer / Developer
1. **Current State**: [00-current-state-inventory.md](./00-current-state-inventory.md) (resource names)
2. **Implementation**: [02-target-architecture.md](./02-target-architecture.md) (code samples)
3. **Deployment**: [03-deployment-plan.md](./03-deployment-plan.md) (Bicep modules)
4. **Validation**: [05-evidence-pack.md](./05-evidence-pack.md) (test commands)
5. **Automation**: Run `az-inventory-finops.ps1` script

### Data Engineer
1. **Architecture**: [02-target-architecture.md](./02-target-architecture.md) (ADX schema, ADF pipelines)
2. **Implementation**: [03-deployment-plan.md](./03-deployment-plan.md) → Phase 2 (Analytics & Ingestion)
3. **Tasks**: [04-backlog.md](./04-backlog.md) → Epic 2 (21 story points)
4. **Validation**: [05-evidence-pack.md](./05-evidence-pack.md) → Section 4 (ADX validation queries)

### QA / Auditor
1. **Baseline**: Run `az-inventory-finops.ps1` for current state
2. **Test Cases**: [05-evidence-pack.md](./05-evidence-pack.md) (validation commands)
3. **Acceptance Criteria**: [04-backlog.md](./04-backlog.md) (per-task AC)
4. **Evidence Collection**: Save JSON outputs from validation commands

---

## Execution Workflow

### Pre-Deployment Checklist
- [ ] Read all 6 documentation files
- [ ] Run `az-inventory-finops.ps1` to capture baseline
- [ ] Verify Azure CLI authentication (`az account show`)
- [ ] Confirm permissions: Reader on subscriptions, Contributor on EsDAICoE-Sandbox
- [ ] Review cost estimate: $350/month incremental
- [ ] Get stakeholder approval for budget

### Deployment Sequence
1. **Week 1-2**: Phase 1 (Storage Foundation)
   - **FOLLOW**: [PHASE1-DEPLOYMENT-CHECKLIST.md](./PHASE1-DEPLOYMENT-CHECKLIST.md) for step-by-step guide
   - **Key Tasks**:
     - Deploy storage containers (raw, processed, archive, checkpoint)
     - Configure lifecycle policy (Bicep deployment)
     - Migrate exports to new hierarchy (PowerShell script with dry-run)
     - Update Cost Management export destinations (Portal)
     - Verify Event Grid system topic metrics
   - **Validate**: Manual CSV upload → Event Grid fires
   - **Evidence**: Run inventory script after completion, save screenshots
   
2. **Week 3-4**: Phase 2 (Analytics & Ingestion)
   - Deploy ADX cluster with Bicep (`03-deployment-plan.md` → Phase 2)
   - Execute ADX schema KQL script (`02-target-architecture.md` → Component 4)
   - Deploy ADF pipelines (`03-deployment-plan.md` → Phase 2)
   - Test: Manual pipeline trigger → CSV ingested to ADX
   
3. **Week 5-7**: Phase 3 (APIM Attribution)
   - Implement APIM base policy (`02-target-architecture.md` → Component 5)
   - Configure App Insights diagnostics
   - Deploy telemetry ingestion pipeline
   - Run backfill pipeline (12 months historical)
   - Validate: `AllocateCostByApp()` function returns accurate splits
   
4. **Week 8-9**: Phase 4 (Governance)
   - Deploy Azure Policy for tag enforcement
   - Configure VNet and private endpoints
   - Implement GitHub Actions CI/CD
   - Final validation: Run all commands from `05-evidence-pack.md`

### Post-Deployment Validation
- [ ] Run `az-inventory-finops.ps1` to capture deployed state
- [ ] Compare output with baseline (diff JSON files)
- [ ] Execute all commands in `05-evidence-pack.md`
- [ ] Verify KPIs meet targets (see `04-backlog.md` → Success Metrics)
- [ ] Generate screenshots for audit trail
- [ ] Update `00-current-state-inventory.md` with deployed resources

---

## Related Resources

### External References
- **Microsoft FinOps Hubs**: https://github.com/microsoft/finops-toolkit
- **Azure Cost Management**: https://learn.microsoft.com/azure/cost-management-billing/
- **Azure Data Explorer**: https://learn.microsoft.com/azure/data-explorer/
- **APIM Policies**: https://learn.microsoft.com/azure/api-management/api-management-policies

### Internal Documentation
- **Project README**: `i:/eva-foundation/14-az-finops/README.md`
- **Marco Inventory**: `i:/eva-foundation/system-analysis/inventory/.eva-cache/current/MARCO-INVENTORY-20260213-155026.md`
- **Azure Best Practices**: `i:/eva-foundation/18-azure-best/` (Azure REST API workarounds, cost optimization)
- **Foundation Layer**: `i:/eva-foundation/07-foundation-layer/` (professional components, patterns)

### Script Locations
- **Inventory Script**: `i:/eva-foundation/14-az-finops/tools/finops/az-inventory-finops.ps1`
- **Output Directory**: `i:/eva-foundation/14-az-finops/tools/finops/out/`
- **Historical Scripts**: `i:/eva-foundation/14-az-finops/scripts/` (export migration, cost analysis)

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-02-17 08:20 AM ET | Marco Presta | Initial index created, 6 deliverables + inventory script |

---

## Document Metadata

**Version**: 1.0.0  
**Status**: Complete - Ready for Implementation  
**Total Documentation**: 6 markdown files (2,890+ lines), 1 PowerShell script (650+ lines)  
**Embedded Code**: 1,500+ lines (Bicep, KQL, JSON, XML, YAML)  
**Estimated Implementation Time**: 9 weeks (4.5 sprints at 15 points/sprint)  
**Incremental Cost**: $350/month (ADX Dev SKU $200/mo + storage/networking $150/mo)

---

**Next Action**: Begin Phase 1 deployment or run `az-inventory-finops.ps1` to capture baseline evidence.

