# Project Plan

<!-- veritas-normalized 2026-02-26 prefix=F14 source=README.md -->
<!-- Last updated: 2026-02-26 | Phase 3 IN PROGRESS -->

## Feature: [DONE] Phase 1 FinOps Enterprise Roadmap [ID=F14-01]

### Story: [DONE] Comprehensive Documentation Delivered [ID=F14-01-001]
<!-- 8 deliverables, 4000+ lines, completed Feb 17, 2026 -->

## Feature: Current Status (February 26, 2026) [ID=F14-02]

### Story: [DONE] What Works — SDK, Portal Exports, ADF Pipeline, ADX [ID=F14-02-001]

### Story: [ACTIVE] What Does NOT Work — SDK pagination >5K rows, no Contributor role [ID=F14-02-002]

### Story: [DONE] Active Exports — EsDAICoESub (10 runs verified), EsPAICoESub [ID=F14-02-003]

## Feature: [DONE] Subscriptions [ID=F14-03]
<!-- EsDAICoESub d2d4e571 + EsPAICoESub 802d84ab scoped to marcosandboxfinopshub storage -->

## Feature: [ACTIVE] Permission Model [ID=F14-04]
<!-- Cost Mgmt Contributor only; Contributor needed for provider registration -->

## Feature: [DONE] Project Structure [ID=F14-05]
<!-- scripts/kql/ + scripts/adf/ + bicep artefacts all in place -->

## Feature: Deployment Roadmap [ID=F14-06]

### Story: [DONE] Phase 0: Data Collection Foundation (COMPLETE - Feb 16, 2026) [ID=F14-06-001]
<!-- 10 consecutive export runs verified, baseline inventory (12 JSON) captured -->

### Story: [DONE] Phase 1: Storage Foundation — COMPLETE Feb 25, 2026 [ID=F14-06-002]
<!-- Tasks 1.1.1-1.1.3 + 1.2.1 + 1.3.1-1.3.2 all done
     - raw/archive/checkpoint containers created
     - lifecycle-policy.json deployed (90d Cool, 180d Archive)
     - migrate-costs-to-raw.ps1: 28 blobs migrated
     - Event Grid -> ADF wired (create-eventgrid-subscription.ps1) -->

### Story: [DONE] Phase 2: Analytics & Ingestion — COMPLETE Feb 26, 2026 [ID=F14-06-003]
<!-- Task 2.1.1: adx-cluster.bicep — marcofinopsadx Dev(No SLA)_Standard_D11_v2, canadacentral, finopsdb
     Task 2.1.2: create-schema.kql + kql/01-09-*.kql — raw_costs, CostExportMapping, apim_usage, NormalizedCosts(), AllocateCostByApp()
     Task 2.2.1: managed-identity.bicep — mi-finops-adf + assign-rbac-roles.ps1
     Task 2.2.2: ls_marcosandbox_blob + ls_marcofinops_adx linked services
     Task 2.2.3: ds_blob_cost_csv + ds_adx_raw_costs datasets
     Task 2.2.4: ingest-costs-to-adx pipeline (RFC4180 escaping fixed)
     Backfill: backfill-historical.ps1 — 28 historical blobs triggered Feb 26 -->

### Story: [IN PROGRESS] Phase 3: APIM Attribution & Telemetry (Weeks 5-7, 13 Story Points) [ID=F14-06-004]
<!-- DONE Feb 26:
       - NormalizedCosts() — tag parsing + pre-apim fallbacks (CostCenter->AiCoE, CallerApp->Pre-APIM, Environment->SubscriptionName)
       - AllocateCostByApp() — 3-tier: header (APIM telemetry) -> tag -> pre-apim
       - deploy-functions.ps1 + exec-kql.ps1 tooling
     PENDING:
       - 3.1 APIM base policy: inject x-caller-app / x-costcenter / x-eva-environment on 50+ EVA-JP APIs
       - 3.2 App Insights diagnostics: 100% sampling, log all APIM requests
       - 3.4 Telemetry ingestion pipeline: App Insights -> apim_usage ADX table -->

### Story: [PLANNED] Phase 4: Reporting & Governance (Weeks 8-9, 21 Story Points) [ID=F14-06-005]
<!-- Power BI reports, Azure Policy tag enforcement, VNet + private endpoints, CI/CD -->

### Story: [DONE] Deployment Timeline Summary [ID=F14-06-006]
<!-- Phase 0: COMPLETE | Phase 1: COMPLETE | Phase 2: COMPLETE | Phase 3: IN PROGRESS | Phase 4: PLANNED -->

## Feature: Quick Start [ID=F14-07]

### Story: [DONE] Ad-Hoc Cost Query (Small Date Ranges) [ID=F14-07-001]

### Story: [DONE] Configure Daily Export (Portal) [ID=F14-07-002]

### Story: [DONE] Historical Backfill via ADF (backfill-historical.ps1) [ID=F14-07-003]

## Feature: [DONE] Lessons Learned (Audit Summary) [ID=F14-08]

### Story: [DONE] Extraction Attempt Timeline (10 attempts, Jan-Feb 2026) [ID=F14-08-001]

## Feature: [DONE] Documentation Quick Links [ID=F14-09]

### Story: [DONE] For Implementation Teams [ID=F14-09-001]

### Story: [DONE] For Executives [ID=F14-09-002]

### Story: [DONE] For Auditors [ID=F14-09-003]
