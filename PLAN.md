# Project Plan

<!-- veritas-normalized 2026-02-26 prefix=F14 source=README.md -->
<!-- Last updated: 2026-02-26 | Phase 3 IN PROGRESS — NormalizedCosts v2 + AllocateCostByApp v2 deployed (tag bug fixed, ESDC dims live) -->

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
<!-- DONE Feb 26 (v1):
       - NormalizedCosts() v1 + AllocateCostByApp() v1 deployed (pre-apim fallbacks, 3-tier)
       - deploy-functions.ps1 + exec-kql.ps1 tooling
     DONE Feb 26 (v2 — tag deep-dive):
       - CRITICAL BUG FIXED: Tags stored without {} — parse_json() returned null for 100% of rows
       - NormalizedCosts() v2: dual-schema (SSC Standard 77.8% + Legacy 22.2%), CanonicalEnvironment
         (Dev/Stage/Prod canonicalized from 7 raw variants), 6 new ESDC chargeback dimensions
         (SscBillingCode, FinancialAuthority, OwnerManager, ClientBu, ProjectDisplayName, IsSharedCost)
       - AllocateCostByApp() v2: uses CanonicalEnvironment + SscBillingCode
       - smoke-test-v2.ps1: 6 queries, evidence saved to evidence/smoke-test-v2-*.json
       - Discovery: ssc_cbrid=2133 (460,208 rows, $477,879), ssc_cbrid=0696 (386 rows, $112)
       - Row coverage: 460,594 of 460,609 rows (99.997%) tagged
     PENDING:
       - 3.1 APIM base policy: inject x-caller-app / x-costcenter / x-eva-environment on 50+ EVA-JP APIs
       - 3.2 App Insights diagnostics: 100% sampling, log all APIM requests
       - 3.4 Telemetry ingestion pipeline: App Insights -> apim_usage ADX table -->

### Story: [PLANNED] Phase 4: Tag FinOps — Full Capability Roadmap [ID=F14-06-005]
<!-- Updated: 2026-02-26 — Full art-of-the-possible captured after domain value analysis

TAG DOMAIN VALUES (Feb 26, 2026 — 460,609 rows, $567,992 total spend):

  CanonicalEnvironment:  Dev=334K rows $391K | Prod=71K $56K | Stage=55K $30K | EsPAICoESub=12 $90K(fallback)
  EffectiveCostCenter:   00014=460K $568K (100% — billing column, no tag diversity yet)
  SscBillingCode:        2133=460K $478K | 0696=386 $112 | empty=15 $90K
  FinancialAuthority:    todd.whitley@hrsdc-rhdcc.gc.ca=444K $470K | empty=14K $98K | poma.ilambo=1.4K $360 | Todd.whitley(case dupe)=26 $0.22
  IsSharedCost:          True=447K rows $471K (83% of spend) | False=13K $97K
  ClientBu:              (empty)=365K $346K (79% untagged!) | AICoE=95K $221K | infrastructure=218 $70
  OwnerManager:          (empty)=365K $346K | Niasha Blake=95K $221K | Eric Cousineau=789 $140 | Niasha Black(TYPO)=174 $63
  ProjectDisplayName:    AiCoE Cognitive Services=370K $259K | Information Assistant=38K $191K | (empty)=44K $116K | AICoE=9K $1.4K
  EffectiveCallerApp:    "1101, 1100"=440K $464K | " 1101, 1100"(leading space)=20K $14K | Pre-APIM=12 $90K
  SecurityClass:         (empty)=428K $562K (93% unclassified) | PROTECTEDB=32K $6.3K

BILLING ANOMALY INVESTIGATION (Feb 26, 2026):
  HEADLINE: Total $567,992 is technically accurate but includes two non-recurring events.

  ANOMALY-01 — Runaway Batch Job: EsDAICoESub, April 2025
    Resource:  infoasst-aisvc-hccld (InfoAssistant AI Service, RG infoasst-cog-svc / no RG)
    What:      Foundry Tools / Translator Text — 958M characters/day × 14 days (Apr 10–24)
               + Azure Language / Standard Text Records (same resource, same period)
    Cost:      Translator Text $144,540 + Azure Language $14,382 = $158,922 CAD
    Nature:    Real consumption — one-time runaway batch translation/NLP job, NOT steady-state
    Evidence:  24 rows × ~$10,794/day | EffectivePrice $11.26/million chars | MeterName "S1 Characters"
    Action:    Exclude from steady-state OpEx baseline; investigate who triggered the batch job

  ANOMALY-02 — PTU Commitment Purchase: EsPAICoESub
    Meter:     Azure OpenAI / Provisioned Managed Regional Unit (rg=empty, ResourceName=empty)
    What:      Provisioned Throughput Unit (PTU) reservation purchase — pre-paid capacity, NOT token consumption
    Cost:      $90,000 CAD (12 rows, spread across months)
    Nature:    Commitment/reservation amortization — CapEx-style, not OpEx run-rate
    Evidence:  rg=empty for all 12 rows; other Provisioned Managed rows (rg set) = $5.16 (360 rows)

  TRUE STEADY-STATE OPEX BASELINE (after removing anomalies):
    Total billed:                         $567,992
    − April 2025 InfoAssist batch job:   −$158,922
    − PTU commitment purchase:            −$90,000
    ─────────────────────────────────────────────
    True operational run-rate:            ~$319,070 CAD/year (~$26,600/month)

  MONTHLY BREAKDOWN (EsDAICoESub | EsPAICoESub):
    2025-02: $8,665  | $7,768
    2025-03: $14,212 | $10,059
    2025-04: $174,044| $10,192  ← SPIKE (Anomaly-01: $158,922 batch job)
    2025-05: $12,408 | $11,264
    2025-06: $12,219 | $11,834
    2025-07: $12,216 | $12,332
    2025-08: $17,686 | $11,533
    2025-09: $19,240 | $11,422
    2025-10: $28,484 | $12,660
    2025-11: $33,765 | $13,006
    2025-12: $23,990 | $14,417
    2026-01: $22,257 | $13,264
    2026-02: $42,556 | $6,486
    NOTE: EsPAICoESub includes $90K PTU commitment spread across all months

DATA QUALITY ISSUES FOUND:
  DQ-01: EffectiveCallerApp — fin_csdid tag contains comma-separated multi-app IDs ("1101, 1100") → need split+trim
  DQ-02: EffectiveCallerApp — " 1101, 1100" has leading space variant (20K rows, $14K) → need trim()
  DQ-03: FinancialAuthority — "Todd.whitley" vs "todd.whitley" case split (26 rows, $0.22) → need tolower()
  DQ-04: OwnerManager — "Niasha Blake" vs "Niasha Black" typo (174 rows, $63) → needs correction in source tags
  DQ-05: ClientBu — 79% empty ($346K unattributed) → Azure Policy enforcement needed
  DQ-06: OwnerManager — 79% empty ($346K) → same root cause as DQ-05
  DQ-07: SecurityClass — 93% unclassified ($562K) → Policy needed for PROTECTED-B workloads
  DQ-08: CanonicalEnvironment "EsPAICoESub" — EsPAICoESub subscription has no env tags → need Policy for SubscriptionName-derived env

PHASE 4A — Chargeback Statements (Highest ROI, 2-3 days):
  - KQL: MonthlyChargebackByAuthority() — per FinancialAuthority monthly statement
  - KQL: SharedCostAllocation() — $471K shared cost split by ClientBu / project weight
  - Script: export-chargeback.ps1 → CSV per FinancialAuthority (todd.whitley, poma.ilambo)
  - Fix DQ-01/02/03 in NormalizedCosts() first (split callerapp, tolower FA, trim)

PHASE 4B — Tag Governance Scorecard (1 day):
  - KQL: TagCoverageScore() — % coverage per tag key, spend-weighted
  - Dashboard tab: top untagged spend (ClientBu $346K, OwnerManager $346K priority)
  - Azure Policy: audit/deny resources without FinancialAuthority + ClientBu

PHASE 4C — Anomaly Detection (2 days):
  - KQL: DailyAnomalyDetection() using series_decompose_anomalies()
  - Alert: OwnerManager spend spike > 2σ → Logic App → Teams/email
  - Alert: New unknown FinancialAuthority value
  - Alert: Dev cost > 30% of Prod for same project

PHASE 4D — Unit Economics (1 day):
  - KQL: CostPerCall() — APIM requests ÷ APIM cost by EffectiveCallerApp
  - KQL: CostPerProject() — cost matrix by ProjectDisplayName × CanonicalEnvironment
  - Metric: cost of PROTECTEDB vs unclassified for equivalent workloads (SecurityClass surcharge)

PHASE 4E — Budget Pacing + Forecast (2 days):
  - KQL: BudgetPacing() — current month ÷ elapsed days × days-in-month per FinancialAuthority
  - KQL: series_fit_line() trend per ClientBu (6-month rolling)
  - Scenario model: "if we add another project like Information Assistant costs?"

PHASE 4F — Automated Reports (3 days):
  - Logic App: monthly chargeback CSV email to todd.whitley + poma.ilambo per SscBillingCode
  - Power BI DirectQuery: NormalizedCosts() as semantic layer base measure
  - Internal REST API: Azure Function exposing AllocateCostByApp() for downstream billing systems
-->

### Story: [DONE] Deployment Timeline Summary [ID=F14-06-006]
<!-- Phase 0: COMPLETE | Phase 1: COMPLETE | Phase 2: COMPLETE | Phase 3: IN PROGRESS (KQL v2 complete; APIM policy + telemetry pending) | Phase 4: PLANNED -->

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
