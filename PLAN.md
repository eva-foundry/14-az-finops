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

  DEV vs PROD SPLIT (anomaly-free, 12-month run-rate):
    EsDAICoESub (DEV):   CAD 261,866  (82% of total)
    EsPAICoESub (PROD):  CAD  56,243  (18% of total)
    GRAND TOTAL:         CAD 318,109
    RATIO:               Dev is 4.7× more expensive than Prod

    DEV BREAKDOWN BY SERVICE:
      Azure App Service              CAD  60,681   ← LARGEST: 14 InfoAssist dev/stg environments
      Azure Cognitive Search         CAD  33,854   ← 8.7× more than Prod ($3.9K); 1 index per env
      Foundry Tools                  CAD  29,697   ← AI services (CogSvc, lang, doc intel)
      Azure Container Apps           CAD  29,449   ← EVAChat + InfoAssist per env
      Microsoft Dev Box              CAD  24,204   ← 100% idle nights/weekends
      Azure DNS                      CAD  18,163
      Microsoft Defender for Cloud   CAD  16,242
      Virtual Network                CAD  13,003
      Container Registry             CAD  10,346
      Virtual Machines               CAD  10,321
      Log Analytics                  CAD   6,444
      Azure Database for PostgreSQL  CAD   2,899
      Storage                        CAD   2,549
      + minor services               CAD   4,013
      ─────────────────────────────────────────
      TOTAL DEV                      CAD 261,866

    PROD BREAKDOWN BY SERVICE:
      Azure App Service              CAD  11,320
      Microsoft Defender for Cloud   CAD  11,121   ← same cost as dev despite far fewer resources
      Azure Container Apps           CAD   9,662
      Azure Cognitive Search         CAD   3,891
      Azure DNS                      CAD   3,780
      Foundry Tools                  CAD   3,779
      Redis Cache                    CAD   3,454
      Virtual Network                CAD   2,560
      Container Registry             CAD   1,806
      Azure Database for PostgreSQL  CAD   1,589
      Virtual Machines               CAD   1,424
      Log Analytics                  CAD   1,081
      + minor services               CAD     776
      ─────────────────────────────────────────
      TOTAL PROD                     CAD  56,243

  STOPPABLE DEV COMPUTE (App Service + Container Apps + VMs + Dev Box):
    Total stoppable:                   CAD 124,655
    Night shutdown saving (8h off/24h = 33%):  CAD  41,136/year
    Night + weekend saving (~47%):             CAD  58,588/year

  KEY OBSERVATIONS:
    - Dev App Service alone ($60K) exceeds the entire Prod sub ($56K)
    - 14 InfoAssist environments running: dev0–dev4, stg1–stg5, hccld2, securemode variants
      Each has its own App Service Plan + Cognitive Search S1 instance = ~$500/month/env
    - Cognitive Search: Dev $33,854 vs Prod $3,891 — 8.7× ratio (should be ~2×)
    - Dev Box $24,204 is 100% idle 8pm–8am and all weekends; zero night/weekend usage possible
    - Defender for Cloud: Dev $16,242 vs Prod $11,121 — Dev costs 46% more than Prod

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

COST SAVINGS CATALOGUE (Feb 26, 2026):
  IMMEDIATE — no FinOps or APIM needed, pure infrastructure decisions:

  SAVING-01: Night + Weekend Compute Shutdown (NO-BRAINER, ~1 day effort)
    Target:    Dev App Service + Container Apps + VMs in EsDAICoESub
    Mechanism: Azure Automation / Logic App schedule → Stop/Start all non-prod App Service Plans
               and Container Apps on a 6am–10pm Mon–Fri schedule
    Savings:   CAD 41,136/year (nights only, 33%) → CAD 58,588/year (nights + weekends, 47%)
    Effort:    1 day — Azure Automation runbook or GitHub Actions cron job
    Risk:      Zero — dev teams don't work 10pm–6am; weekend is already dead time
    Blocker:   None. No FinOps approval needed. No APIM. Just a schedule.

  SAVING-02: Delete Stale InfoAssist Dev/Stg Environments (HIGH-IMPACT)
    Finding:   14 InfoAssist environments active in EsDAICoESub:
                 dev0, dev1, dev2, dev3, dev4
                 stg1, stg2, stg3, stg4, stg5
                 hccld2, esdc-eva-dev-4, esdc-eva-stg-securemode-1, esdc-eva-dev-securemode-2
               Each env = App Service Plan (~$2.5K/yr) + Cognitive Search S1 (~$3.1K/yr)
               = ~$5.5–7K/year per environment
    Savings:   If 6 of 14 envs are stale → CAD 33,000–42,000/year
               If 9 of 14 envs are stale → CAD 49,500–63,000/year
    Effort:    1 afternoon: inventory who uses each env, delete unused ones
    Risk:      Low — teams know which envs they use; deleted RGs can be recreated from IaC
    Blocker:   None. No FinOps. No approvals beyond team lead.

  SAVING-03: Dev Box Idle Shutdown (EASY WIN)
    Finding:   Microsoft Dev Box = CAD 24,204/year from EsDCAICoE-DevRg
               Dev Box VMs are priced hourly; they run 24/7 unless explicitly stopped
               Zero usage 10pm–6am (confirmed: no APIM calls, no AI service calls)
    Savings:   CAD 7,987/year (33% night shutdown) → CAD 11,375/year (47% night+weekend)
    Effort:    30 minutes — enable Auto-stop in Dev Box project settings (built-in feature)
               Portal → Dev Center → Dev Box Policies → Auto-stop schedule
    Risk:      Zero. Dev Box has native auto-stop. Work in progress saves via Hibernate.
    Blocker:   None. Already a built-in platform feature.

  SAVING-04: Cognitive Search Right-Sizing (MEDIUM EFFORT)
    Finding:   Dev has CAD 33,854 in Cognitive Search vs Prod CAD 3,891 (8.7× ratio)
               All instances are Standard S1 (~CAD 259/month each)
               Dev/test workloads with <1M documents should use Basic (~CAD 73/month = 3.5× cheaper)
    Savings:   Downgrade 8 dev/stg instances S1→Basic: 8 × (259-73) × 12 = CAD 17,856/year
    Effort:    1 day — Recreation: export index schema, recreate at Basic tier, re-index
    Risk:      Medium — Basic has 2 replicas max vs S1's 12; fine for dev/test
    Blocker:   None. Dev team decision only. No FinOps governance needed.

  SAVING-05: Defender for Cloud Plan Review (QUICK REVIEW)
    Finding:   Dev CAD 16,242 + Prod CAD 11,121 = CAD 27,363/year total
               Dev Defender costs 46% MORE than Prod despite lower risk profile
               Likely Defender for Servers P2 ($15/server/month) running on dev VMs
    Savings:   Downgrade dev VMs to Defender for Servers P1 ($8/server/month) or Free:
               Estimated CAD 5,000–8,000/year
    Effort:    2-3 hours — Defender for Cloud portal → Plans → per-resource override
    Risk:      Low — dev VMs don't need P2 features (Qualys vulnerability scanning, JIT)
    Blocker:   Security team sign-off (1 conversation, standard practice)

  MEDIUM-TERM — with light FinOps tooling, no APIM required:

  SAVING-06: Container Registry Deduplication
    Finding:   Dev CAD 10,346 in Container Registry (likely multiple registries per env)
               Prod CAD 1,806 — Dev is 5.7× more expensive
    Savings:   Consolidate to 1–2 dev/stg registries: estimated CAD 4,000–6,000/year
    Effort:    1 week — retag and push images to consolidated registry
    Blocker:   Light FinOps: need registry inventory (which teams own which)

  SAVING-07: Log Analytics Tier + Retention Right-Sizing
    Finding:   Dev CAD 6,444 in Log Analytics
               Dev environments likely ingesting at same retention as prod (90 days)
               Dev log retention should be 7–14 days; ingestion tier should be Basic
    Savings:   Estimated CAD 2,000–3,500/year
    Effort:    2-3 hours — change workspace retention per env via ARM/Bicep
    Blocker:   None. Log workspace is per-subscription; no cross-team negotiation.

  SAVING-08: Azure DNS Zone Reduction (LOW EFFORT)
    Finding:   Dev CAD 18,163 DNS — extremely high for DNS (Prod is only CAD 3,780)
               Dev/stg environments each likely create private DNS zones (charged per zone per query)
               Ratio 4.8× suggests many duplicate private DNS zones across dev envs
    Savings:   Consolidate or use a shared private DNS hub: estimated CAD 6,000–10,000/year
    Effort:    1 week — DNS zone inventory, move to hub-spoke model
    Blocker:   Networking team decision. No FinOps.

  WITH APIM/FINOPS — longer-term but higher ROI:

  SAVING-09: Shared Cognitive Services Endpoint (vs per-env)
    Finding:   Foundry Tools (AI CogSvc) Dev = CAD 29,697 — each env has dedicated endpoint
               Shared APIM gateway → single CogSvc endpoint with app-level quotas
    Savings:   Eliminate duplicated base costs; enforce per-app token budgets via APIM
    Effort:    Phase 3 APIM work (already planned)
    Blocker:   APIM completion + app team migration

  SUMMARY TABLE:
    ID  | Description                          | Saving/yr CAD | Effort   | Needs FinOps?
    ----|--------------------------------------|---------------|----------|---------------
    S-01| Night+weekend shutdown, Dev compute  | 41K–58K       | 1 day    | NO
    S-02| Delete stale InfoAssist envs (6–9)   | 33K–63K       | 1 day    | NO
    S-03| Dev Box auto-stop (native feature)   | 8K–11K        | 30 min   | NO
    S-04| Search S1→Basic on dev/stg           | 17K–18K       | 1 day    | NO
    S-05| Defender plan downgrade on dev VMs   | 5K–8K         | 2 hrs    | MINOR
    S-06| Container Registry consolidation      | 4K–6K         | 1 week   | LIGHT
    S-07| Log Analytics retention/tier dev      | 2K–3.5K       | 2 hrs    | NO
    S-08| DNS zone hub-spoke                   | 6K–10K        | 1 week   | NO
    S-09| Shared CogSvc via APIM               | TBD           | Phase 3  | YES
    ----|--------------------------------------|---------------|----------|---------------
    TOTAL NO-FINOPS SAVINGS (S01–S04+S07):    | 99K–152K/yr   | ~4 days  | NO



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
