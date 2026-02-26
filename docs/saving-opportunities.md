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

> *[In progress — see next section]*

---
