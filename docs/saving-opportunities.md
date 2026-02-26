# Cost Saving Opportunities
> Generated: February 26, 2026  
> Data: 12-month run-rate, anomalies excluded (−$158K April 2025 batch job, −$90K PTU commitment)  
> Subscriptions: EsDAICoESub (Dev) · EsPAICoESub (Prod)

---

## Baseline: Dev vs Prod Split

| Subscription | Annual CAD | % of Total |
|---|---|---|
| EsDAICoESub **(DEV)** | $261,866 | 82% |
| EsPAICoESub **(PROD)** | $56,243 | 18% |
| **Grand Total** | **$318,109** | |

> **Dev is 4.7× more expensive than Prod.**  
> Dev App Service alone ($60,681) costs more than the entire Prod subscription ($56,243).

---

### DEV — Service Breakdown

| Service | CAD/yr | Notes |
|---|---|---|
| Azure App Service | $60,681 | 14 InfoAssist environments |
| Azure Cognitive Search | $33,854 | All S1 — 8.7× more than Prod |
| Foundry Tools (AI CogSvc) | $29,697 | AI services per env |
| Azure Container Apps | $29,449 | EVAChat + InfoAssist per env |
| Microsoft Dev Box | $24,204 | 100% idle nights & weekends |
| Azure DNS | $18,163 | 4.8× more than Prod |
| Microsoft Defender for Cloud | $16,242 | 46% more than Prod |
| Virtual Network | $13,003 | |
| Container Registry | $10,346 | 5.7× more than Prod |
| Virtual Machines | $10,321 | |
| Log Analytics | $6,444 | Over-retained dev logs |
| Azure Database for PostgreSQL | $2,899 | |
| Storage | $2,549 | |
| + minor services | $4,013 | |
| **TOTAL DEV** | **$261,866** | |

### PROD — Service Breakdown

| Service | CAD/yr | Notes |
|---|---|---|
| Azure App Service | $11,320 | |
| Microsoft Defender for Cloud | $11,121 | |
| Azure Container Apps | $9,662 | |
| Azure Cognitive Search | $3,891 | |
| Azure DNS | $3,780 | |
| Foundry Tools | $3,779 | |
| Redis Cache | $3,454 | |
| Virtual Network | $2,560 | |
| Container Registry | $1,806 | |
| Azure Database for PostgreSQL | $1,589 | |
| Virtual Machines | $1,424 | |
| Log Analytics | $1,081 | |
| + minor services | $776 | |
| **TOTAL PROD** | **$56,243** | |

---

## Part 1 — Savings Without FinOps (Infrastructure Decisions Only)

> These require no FinOps tooling, no APIM, no governance framework.  
> Pure infrastructure decisions: a schedule, a delete, a tier change.

---

### S-01 · Night + Weekend Compute Shutdown ⭐ HIGHEST ROI

| | |
|---|---|
| **Target** | Dev App Service Plans + Container Apps + VMs in EsDAICoESub |
| **Total stoppable compute** | CAD $124,655/year |
| **Night-only saving (8h off / 24h = 33%)** | **CAD $41,136/year** |
| **Night + weekend saving (~47%)** | **CAD $58,588/year** |
| **Effort** | 1 day |
| **Mechanism** | Azure Automation Runbook or GitHub Actions cron: Stop all App Service Plans + Container Apps at 10pm, Start at 6am Mon–Fri |
| **Risk** | Zero — no developer works 10pm–6am; weekends confirmed zero usage |
| **FinOps needed?** | ❌ No |

**Stoppable resources in Dev:**

| Category | Resource Group | CAD/yr |
|---|---|---|
| Microsoft Dev Box | EsDCAICoE-DevRg | $24,193 |
| Azure Container Apps | EVAChatStgRg, EVAChatDevRg, EVAChatDev2Rg, EVAChatDev3Rg, EVAChatStg2Rg | $29,449 total |
| Azure App Service (Standard Linux) | infoasst-esdc-eva-stg-*, infoasst-dev0–dev4 | ~$22,000 |
| Azure App Service (Premium Linux) | infoasst-* various | ~$18,000 |
| Virtual Machines | ESDCAICOE-DEVRG, ESDCAICOE-CORG, ESDCAICOE-COSTARG | ~$10,321 |

---

### S-02 · Delete Stale InfoAssist Environments

| | |
|---|---|
| **Finding** | 14 InfoAssist environments running in EsDAICoESub |
| **Environments** | dev0, dev1, dev2, dev3, dev4, stg1, stg2, stg3, stg4, stg5, hccld2, esdc-eva-dev-4, esdc-eva-stg-securemode-1, esdc-eva-dev-securemode-2 |
| **Cost per env** | ~$5,500–$7,000/yr (App Service Plan ~$2.5K + Cognitive Search S1 ~$3.1K) |
| **Saving if 6 envs deleted** | **CAD $33,000–$42,000/year** |
| **Saving if 9 envs deleted** | **CAD $49,500–$63,000/year** |
| **Effort** | 1 afternoon — inventory who uses each env, delete unused RGs |
| **Risk** | Low — environments are recreatable from IaC in <30 min |
| **FinOps needed?** | ❌ No — team lead decision |

---

### S-03 · Dev Box Auto-Stop (Native Platform Feature)

| | |
|---|---|
| **Finding** | Dev Box = CAD $24,204/year from EsDCAICoE-DevRg. Zero usage confirmed nights/weekends. |
| **Mechanism** | Dev Box project has a built-in **Auto-stop schedule** — already supported in portal |
| **Saving (33% nights)** | **CAD $7,987/year** |
| **Saving (47% nights+weekends)** | **CAD $11,375/year** |
| **Effort** | **30 minutes** — Portal → Dev Center → Dev Box Policies → Auto-stop schedule |
| **Risk** | Zero — Hibernate preserves in-progress work |
| **FinOps needed?** | ❌ No |

---

### S-04 · Cognitive Search Right-Sizing (S1 → Basic on Dev/Stg)

| | |
|---|---|
| **Finding** | All dev/stg instances run Standard S1 (~CAD $259/month each). Basic tier = ~CAD $73/month (3.5× cheaper). Fine for dev workloads with <1M docs. |
| **Dev total Search** | CAD $33,854/year vs Prod $3,891 (8.7× ratio — should be ~2×) |
| **Target** | 8 dev/stg instances: infoasst-dev0–dev4, infoasst-stg1–stg3 |
| **Saving** | 8 × ($259 − $73) × 12 = **CAD $17,856/year** |
| **Effort** | 1 day — export schema, recreate at Basic tier, re-index |
| **Risk** | Medium — Basic cap: 2 replicas, 5 indexes. Verify index counts first. |
| **FinOps needed?** | ❌ No — dev team decision |

---

### S-05 · Defender for Cloud Plan Downgrade on Dev

| | |
|---|---|
| **Finding** | Dev Defender = CAD $16,242/year — 46% more than Prod ($11,121) despite lower risk. Likely Defender for Servers P2 ($15/server/month) on dev VMs that don't need it. |
| **Saving** | Downgrade dev VMs to P1 ($8/server) or exclude from Defender: **CAD $5,000–$8,000/year** |
| **Effort** | 2–3 hours — Defender portal → Plans → per-resource override |
| **Risk** | Low — dev VMs don't need Qualys vulnerability scanning or JIT access |
| **FinOps needed?** | Minor — 1 conversation with security team (standard practice) |

---

### S-07 · Log Analytics Retention Right-Sizing

| | |
|---|---|
| **Finding** | Dev Log Analytics = CAD $6,444/year. Dev workspaces likely retain logs at 90 days (same as prod). Should be 7–14 days. |
| **Saving** | **CAD $2,000–$3,500/year** |
| **Effort** | 2–3 hours — update workspace retention via ARM/portal per dev workspace |
| **Risk** | None for dev — no compliance requirement for dev log retention |
| **FinOps needed?** | ❌ No |

---

### S-08 · Azure DNS Hub-Spoke (Dev DNS is 4.8× Prod)

| | |
|---|---|
| **Finding** | Dev DNS = CAD $18,163/year vs Prod $3,780. Each dev/stg env likely creates isolated private DNS zones (charged per zone + per query). |
| **Saving** | Consolidate to shared private DNS hub: **CAD $6,000–$10,000/year** |
| **Effort** | 1 week — DNS zone inventory + hub-spoke refactor |
| **Risk** | Medium — requires networking coordination |
| **FinOps needed?** | ❌ No — networking team decision |

---

### Medium-Term Infrastructure

| # | Action | Saving/yr | Effort |
|---|---|---|---|
| S-06 | Container Registry consolidation (Dev 5.7× Prod) | $4K–$6K | 1 week |

---

### Part 1 Summary

| ID | Action | Saving/yr CAD | Effort | FinOps? |
|---|---|---|---|---|
| **S-01** | Night + weekend shutdown | **$41K–$58K** | 1 day | ❌ |
| **S-02** | Delete stale InfoAssist envs | **$33K–$63K** | 1 afternoon | ❌ |
| **S-03** | Dev Box auto-stop | **$8K–$11K** | 30 min | ❌ |
| **S-04** | Cognitive Search S1→Basic | **$17K–$18K** | 1 day | ❌ |
| **S-05** | Defender plan downgrade | $5K–$8K | 2 hrs | Minor |
| **S-07** | Log Analytics retention | $2K–$3.5K | 2 hrs | ❌ |
| **S-08** | DNS hub-spoke | $6K–$10K | 1 week | ❌ |
| **S-06** | Container Registry consolidation | $4K–$6K | 1 week | Light |
| | | | | |
| **TOTAL (S-01+S-02+S-03+S-04+S-07, ~4 days)** | | **$101K–$153K/yr** | **~4 days** | **❌** |

> Saving 31–48% of the entire $318K annual run-rate in approximately 4 days of work.

---

## Part 2 — Savings With FinOps Findings

> These require FinOps tooling, governance policies, or platform investment.  
> Higher ceiling, one-time setup cost, durable benefit.

---

### F-01 · Reserved Instances / Azure Savings Plans ⭐ BEST MEDIUM-TERM ROI

**Methodology:** Coefficient of Variation (CV%) measures month-to-month spend consistency.  
Lower CV% = more predictable = better Reserved Instance fit.  
Threshold: CV < 60% = eligible | CV < 35% = excellent candidate.

**Total annual spend in RI-eligible categories (CV < 60%):** CAD $146,343

| Sub | Service | Annual CAD | CV% | Rating | RI Saving @35% |
|---|---|---|---|---|---|
| Dev | **Azure Container Apps** | $27,183 | 17.5% | ⭐⭐⭐ EXCELLENT | **$9,514** |
| Dev | **Microsoft Dev Box** | $22,342 | 26.1% | ⭐⭐ GOOD | **$7,820** |
| Dev | Container Registry | $9,550 | 32.5% | ⭐⭐ GOOD | $3,342 |
| Dev | Virtual Machines | $9,527 | 35.5% | ⭐⭐ GOOD | $3,335 |
| Dev | Microsoft Defender | $14,993 | 39.7% | ⭐⭐ GOOD | $5,248 |
| Prod | Virtual Machines | $1,314 | 23.2% | ⭐⭐⭐ EXCELLENT | $460 |
| Prod | Container Apps | $8,919 | 32.0% | ⭐⭐ GOOD | $3,121 |
| Prod | App Service | $10,449 | 36.3% | ⭐⭐ GOOD | $3,657 |
| Prod | Cognitive Search | $3,592 | 37.2% | ⭐⭐ GOOD | $1,257 |
| Prod | Microsoft Defender | $11,121 | 56.6% | ★ FAIR | $3,892 |
| Dev | Storage | $2,353 | 29.1% | ⭐⭐ GOOD | $824 |
| Dev + Prod | Redis Cache | $4,567 | 47.8% | ★ FAIR | $1,598 |
| (+ other eligible) | | | | | |

| Scenario | Annual Saving |
|---|---|
| Conservative — Azure Savings Plan 1yr (@17%) | **CAD $24,877** |
| Aggressive — Reserved Instances 1yr (@35%) | **CAD $51,219** |

> **Recommended action:** Purchase 1-year Compute Savings Plan covering Dev Container Apps + Dev Box first  
> (CAD $49,525 combined, CV < 27%, saving $8,700–$17,300/yr).  
> Requires Finance approval + FinOps governance to track commitment utilisation.

---

### F-02 · Anomaly Detection — Prevent Runaway Batch Jobs ⭐⭐ CRITICAL

**Backtest: April 2025 InfoAssist Translator Text / Foundry Tools incident**

| Date | Daily Spend | Cumulative | Status |
|---|---|---|---|
| Apr 2 | CAD $1.12 | $1.12 | First alert triggers (3× baseline) |
| Apr 7 | CAD $0 | $1.57 | — |
| **Apr 10** | **CAD $3,399** | **$3,401** | **Spike begins — series_decompose_anomalies() fires** |
| Apr 11 | CAD $10,794 | $14,195 | +3σ alert |
| Apr 12 | CAD $10,794 | $24,989 | +3σ alert |
| Apr 13–20 | ~CAD $10,800/day | $35K → $111K | Unchecked |
| Apr 23 | CAD $10,408 | $143,530 | Last full spike day |
| Apr 24 | CAD $1,011 | $144,541 | Job ends |

| | CAD |
|---|---|
| **Total April Foundry Tools spend** | **$159,883** |
| Cost if stopped on day 1 of spike (Apr 10) | $3,401 |
| **Potential saving with KQL anomaly alert** | **$156,482** |

**Implementation:**  
- KQL `series_decompose_anomalies()` on daily AI spend per ServiceName  
- Alert rule: daily spend > 3× 30-day rolling average → P1 ticket + auto-disable endpoint  
- `scripts/kql/10-anomaly-detection.kql` (to be created)

> This is the single highest-value FinOps action. One incident = $159K. Setup time = 1 day.  
> **This incident will recur** until quotas + alerting are in place.

---

### F-03 · Shared Cost Chargeback → Behavioural Reduction

**Current state:** 83% of all spend is tagged `IsSharedCost=True`.  
**Without FinOps:** All $470,919 falls on CostCenter 00014. No team sees their bill. No incentive to reduce.

| Project | Shared Cost (unallocated) | Proportional % |
|---|---|---|
| AI Centre of Excellence — Cognitive Services | $252,303 | 54% |
| Information Assistant | $190,739 | 41% |
| (untagged projects) | $26,443 | 5% |
| AICoE | $1,435 | <1% |
| **TOTAL unallocated** | **$470,919** | |

**With FinOps chargeback:**  
Each team receives a monthly bill showing their proportional share of shared services.  
Historical benchmark: 15–25% behavioural spend reduction within 2–3 billing cycles.

| Saving scenario | CAD/year |
|---|---|
| Conservative @15% | $70,638 |
| **Expected @20%** | **$94,184** |
| Optimistic @25% | $117,730 |

**Implementation:** AllocateCostByApp() v2 already deployed (Phase 2).  
Requires: monthly report distribution per team + executive sponsorship.

---

### F-04 · Tag Coverage Enforcement → Team Accountability

**Current state:**

| | Annual Spend | % |
|---|---|---|
| Tagged (ClientBu known) | $221,525 | 39% |
| **Untagged (no ClientBu)** | **$346,467** | **61%** |

> 61% of spend — **$346K — has no team owner**. Nobody receives a bill. Nobody has incentive to reduce it.

**Why untagged resources cost more:**  
Teams that see their bill reduce consumption. Teams with no bill do not.  
Assumption: untagged resources are on average 15–20% over-provisioned vs tagged.

| Saving scenario | CAD/year |
|---|---|
| Conservative @15% after tagging | **$51,970** |
| Expected @20% | $69,293 |

**Implementation:**  
- Azure Policy: deny deployment if `ClientBu` tag is missing (Prod)  
- AWS-style tagging sprint: 2 weeks to tag all existing resources  
- Monthly untagged spend report → escalation to resource owners

---

### F-05 · Redis Cache Reserved Instances

| Sub | Tier | Resource Group | Annual CAD |
|---|---|---|---|
| **Prod** | Standard C4 | EVAChatPrdRg | $3,454 |
| Dev | Basic C1 | EVAChatDev3Rg | $367 |
| Dev | Basic C1 | EVAChatStg2Rg | $364 |
| Dev | Basic C0 | EsDAICoE-Sandbox | $349 |
| Dev | Memory Optimised M10 | EsDAICoE-AI-Foundry-rg | $33 |
| **Total** | | | **$4,567** |

> Redis Reserved Instances available at **~35% discount** (1-year commitment).  
> **Saving: CAD $1,598/year** — low-effort, low-risk, purely financial.

---

### F-06 · APIM Token Budget Enforcement → Prevents Future $100K+ Incidents

**Current state:** No per-app AI token quotas exist.  
The April 2025 batch job consumed 958M characters/day for 14 days — **with zero automated blocking**.

| App | Service | Sub | Annual Spend |
|---|---|---|---|
| app 1101/1100 | Foundry Tools | Dev | $189,581 |
| Pre-APIM (no quota) | Foundry Models | Prod | $90,000 |
| app 1101/1100 | Foundry Tools | Prod | $3,779 |

**APIM enforcement architecture:**  
- `x-caller-app` header → per-app routing in APIM  
- Token-counting policy: `azure-openai-token-limit` per app per day  
- Budget cap: e.g. Translator Text → 10M chars/day per app → auto-403 at threshold  
- Alert: 80% budget consumed → notify app owner

**Quantified impact:**  
- April 2025 incident: APIM would have blocked on **day 1** → saving **CAD $156,000**  
- Ongoing enforcement prevents ad-hoc batch jobs from appearing in the bill undetected  
- Phase 3 APIM work (scripts/kql/apim-token-analysis.kql) already partially deployed

> **This is an insurance policy**, not a recurring saving.  
> Cost to implement: ~3 days of APIM policy work.  
> Value: prevents any future runaway AI batch job.

---

### Part 2 Summary

| ID | Action | Saving/yr CAD | Effort | Type |
|---|---|---|---|---|
| **F-01** | RI / Savings Plans (CV<35% services) | **$25K–$51K** | 1 week + Finance | Commitment |
| **F-02** | Anomaly detection alerting | **$156K/incident** | 1 day KQL | Prevention |
| **F-03** | Shared cost chargeback | **$70K–$118K** | 2 weeks + exec | Behavioural |
| **F-04** | Tag coverage enforcement | **$52K–$69K** | 2 weeks | Governance |
| **F-05** | Redis Cache RI | **$1,598** | 1 hr | Commitment |
| **F-06** | APIM token budgets | **TBD, $156K+ per incident** | 3 days | Prevention |

| Scenario | Annual Saving (excluding anomaly prevention) |
|---|---|
| Conservative (F-01 Savings Plan + F-03 min + F-04 min + F-05) | **CAD ~$148K/yr** |
| Expected (F-01 RI + F-03 expected + F-04 conservative + F-05) | **CAD ~$219K/yr** |

---

## Combined Savings View

| | Part 1 (No FinOps) | Part 2 (FinOps) | TOTAL |
|---|---|---|---|
| **Conservative** | $101K | $148K | **$249K/yr** |
| **Expected** | $127K | $219K | **$346K/yr** |
| **Optimistic** | $153K | $250K+ | **$403K+/yr** |

> **Current run-rate: $318K/yr.**  
> The expected combined saving **exceeds the entire annual budget** — primarily driven by eliminating  
> 14 redundant dev environments (S-02) and implementing cost accountability (F-03, F-04).  
> This is achievable in 1–2 quarters with Executive sponsorship and a dedicated FinOps sprint.

> *[In progress — see next section]*

---
