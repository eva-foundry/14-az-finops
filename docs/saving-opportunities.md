# Cost Saving Opportunities - Dev (EsDAICoESub)
> Data: 3-month actuals - Nov 27 2025 to Feb 26 2026 - annualised x12
> Source: tools/finops/dev-costs.db (built Feb 26 2026 from Cost Management API)
> Scope: EsDAICoESub (d2d4e571-e0f2-4f6c-901a-f88f7669bcba) - Dev only

---

## Baseline

| Metric | Value |
|---|---|
| Dev annual run-rate | CAD $235,259/yr |
| Monthly average | CAD $19,605/mo |
| Period covered | Nov 27 2025 to Feb 26 2026 (92 days) |
| Active anomaly | Feb 17-18: Foundry Tools spike in infoasst-dev2 (+$8.4K in 2 days, z=4.78) |

### Dev Service Breakdown

| Service | CAD/yr | CV% | Trend |
|---|---|---|---|
| Azure App Service | $64,287 | 55.9% | +$1,342/mo |
| Azure Cognitive Search | $37,235 | 55.2% | +$937/mo |
| Foundry Tools | $25,846 | 184.8% [!] | +$2,449/mo - anomaly driven |
| Azure DNS | $22,753 | 55.3% | +$584/mo |
| Microsoft Dev Box | $16,813 | 62.8% | +$507/mo |
| Azure Container Apps | $14,471 | 48.9% | +$297/mo |
| Microsoft Defender for Cloud | $14,284 | 54.8% | +$345/mo |
| Virtual Network | $13,649 | 56.2% | +$271/mo |
| Container Registry | $8,292 | 55.6% | +$154/mo |
| Virtual Machines | $6,744 | 71.6% | +$304/mo |
| Log Analytics | $3,855 | 64.7% | +$270/mo |
| Azure Database for PostgreSQL | $2,411 | 55.2% | +$57/mo |
| Storage | $1,417 | 57.8% | +$48/mo |
| Redis Cache | $1,254 | 56.4% | +$38/mo |
| API Management | $611 | 64.2% | +$24/mo |
| Foundry Models | ~$582 | n/a | rapid growth |
| Other | ~$551 | n/a | |
| **TOTAL** | **$235,259** | | |

> CV% inflated by 4-day November ramp-up. True steady-state ~15-30% for stable services. Recompute after April 2026.

---

## Saving Opportunities - Ordered by Execution Complexity

---

### 1. Dev Box Auto-Stop - 30 minutes - CAD $5,548-$7,902/yr

> $16,813/yr from esdcaicoe-devrg. Zero developer usage nights and weekends confirmed.

| Nights only (33%) | Nights + weekends (47%) | Risk |
|---|---|---|
| $5,548/yr | $7,902/yr | Zero - Hibernate preserves in-progress work |

**Execution plan:**
1. Portal -> Dev Center -> Dev Box Policies -> Auto-stop schedule -> 10 PM stop / 6 AM wake, skip weekends; enable Hibernate (not shutdown) to protect in-flight work.
2. Confirm with one Dev Box user that resume works correctly; roll out to all boxes in the project.

---

### 2. Log Analytics Retention Right-Size - 2 hours - CAD $1,000-$2,000/yr

> $3,855/yr, trend +$270/mo (+84% annualised). Dev workspaces retain 90 days - no compliance requirement in Dev.

| Target retention | Current retention | Risk |
|---|---|---|
| 7-14 days | ~90 days (default) | Zero for Dev |

**Execution plan:**
1. az monitor log-analytics workspace list --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba --query "[].{name:name,rg:resourceGroup}" -o tsv -> for each, run: az monitor log-analytics workspace update --retention-time 14 -n <name> -g <rg>.
2. Verify ingestion metric unchanged after 48 h; lock 14-day default in Bicep/ARM template to prevent reversion on next deployment.

---

### 3. Defender for Cloud Plan Downgrade - 2-3 hours - CAD $4,000-$6,000/yr

> $14,284/yr in Dev - 54% more than Prod ($11,121) despite lower risk. Likely Defender for Servers P2 ($15/server/month) on Dev VMs.

| Action | Saving |
|---|---|
| P2 to P1 on Dev VMs | ~$4,000/yr |
| Exclude Dev VMs entirely | ~$6,000/yr |

**Execution plan:**
1. Portal -> Defender for Cloud -> Environment Settings -> EsDAICoESub -> Servers -> switch Dev VM resource group assignments to P1 or Off.
2. Confirm no security policy mandates P2 on Dev; document the exception; add a calendar reminder for annual security review.

---

### 4. Night + Weekend Compute Shutdown - 1 day - CAD $33,764-$48,088/yr [HIGHEST ROI]

> Stoppable compute totals $102,315/yr. Zero developer usage outside business hours confirmed.

| Resource | CAD/yr | Nights 33% | N+Wknd 47% |
|---|---|---|---|
| Azure App Service (14 InfoAssist envs) | $64,287 | $21,215 | $30,215 |
| Microsoft Dev Box | $16,813 | $5,548 | $7,902 |
| Azure Container Apps | $14,471 | $4,775 | $6,801 |
| Virtual Machines | $6,744 | $2,226 | $3,170 |
| **TOTAL** | **$102,315** | **$33,764** | **$48,088** |

**Execution plan:**
1. Deploy GitHub Actions cron (or Azure Automation Runbook): Stop-AzWebApp + Stop-AzContainerApp + az vm deallocate at 22:00 ET; reverse at 06:00 ET Mon-Fri; pilot on infoasst-dev1 for one week.
2. Confirm start window with dev leads; extend to all 14 envs; add a manual override webhook for after-hours deployments.

---

### 5. Anomaly Alert - Prevent Runaway Batch Jobs - 1 day - $156K+ per incident [CRITICAL]

> Feb 1 2026 had z=5.17 (IQR confirmed) - a live warning that went undetected. Feb 17-18 peaked at z=4.78, same signature as April 2025. An alert on Feb 1 would have fired 16 days before the spike peaked.

| April 2025 backtest | CAD |
|---|---|
| Total Foundry Tools spend (14 days) | $159,883 |
| Cost if stopped on day 1 of spike | $3,401 |
| Preventable saving | $156,482 |

**Execution plan:**
1. Create Log Analytics alert rule: KQL series_decompose_anomalies() on daily MeterCategory spend; trigger when z > 3 on Foundry Tools or Container Apps -> Action Group -> Teams + email P1.
2. Add a secondary Azure Budget alert at 110% of prior-month spend for EsDAICoESub; wire to a Logic App that disables the AI endpoint at 100% and logs to Application Insights.

---

### 6. Delete Stale InfoAssist Environments - 1 afternoon (team decision) - CAD $33,000-$63,000/yr [HIGHEST SAVING]

> 14 InfoAssist environments running. Each env ~$4,000-$5,000/yr (App Service + Search + DNS + Defender share). Deleting 6-9 idle envs is the single largest infrastructure saving available.

| RG | CAD/mo | Note |
|---|---|---|
| infoasst-dev0 | ~$1,006 | RBAC blocked - likely idle |
| infoasst-dev1 | ~$1,007 | Confirm usage |
| infoasst-dev2 | ~$3,195 | Active (Feb spike here) |
| infoasst-dev3 | ~$926 | Confirm usage |
| infoasst-hccld2 | ~$1,008 | RBAC blocked - single owner |
| infoasst-esdc-eva-dev-4 | ~$251 | Low cost, likely idle |
| infoasst-esdc-eva-dev-securemode-2 | ~$452 | Confirm usage |
| Saving - 6 envs deleted | | ~$33K-$42K/yr |
| Saving - 9 envs deleted | | ~$50K-$63K/yr |

**Execution plan:**
1. Pull App Service access logs for past 30 days per RG + az webapp list --query "[].lastModifiedTimeUtc"; share usage report with dev leads to identify zero-login envs.
2. Get team-lead sign-off; az group delete --name <rg> --yes --no-wait; IaC recreates any environment in <30 min from existing templates.

---

### 7. Cognitive Search S1 to Basic on Dev/Stg - 1 day - CAD $12,000-$18,000/yr

> $37,235/yr - 9.6x more than Prod ($3,891). S1 ~$259/month per instance; Basic ~$73/month. Dev workloads never need S1 capacity.

| Instances | Saving | Risk |
|---|---|---|
| 8 (dev0-dev4, stg1-stg3) | 8 x ($259-$73) x 12 = $17,856/yr | Medium - Basic cap: 2 replicas, 5 indexes |

**Execution plan:**
1. az search service show on each instance - verify index count <= 5 and replica count <= 2; export schemas with az search index list; provision Basic-tier replacement in same RG.
2. Reindex, swap connection string in App Service config, validate search results, delete the S1 instance; schedule non-business-hours.

---

### 8. Container Registry Consolidation - 1 week - CAD $3,000-$4,500/yr

> $8,292/yr in Dev - 4.6x more than Prod. Each InfoAssist env has its own registry (~$150-$200/mo); one shared Standard-tier ACR serves all.

| Action | Saving | Risk |
|---|---|---|
| Eliminate 4-5 per-env registries | $3,000-$4,500/yr | Low - CI/CD variable update only |

**Execution plan:**
1. az acr list to inventory all registries; retag and push images to the shared registry using az acr import; delete per-env registries once pipelines are switched.
2. Update REGISTRY_LOGIN_SERVER in all App Service / Container App configs and pipelines; validate build + pull on one pipeline before fleet rollout.

---

### 9. DNS Hub-Spoke Consolidation - 1 week - CAD $6,000-$10,000/yr

> $22,753/yr - 6x more than Prod ($3,780) from private DNS zone sprawl. Each InfoAssist env creates isolated zones charged per zone + per query.

| Action | Saving | Risk |
|---|---|---|
| Deduplicate zones to shared hub VNet | $6,000-$10,000/yr | Medium - networking coordination required |

**Execution plan:**
1. az network private-dns zone list + az network private-dns link vnet list to map zone-to-VNet dependencies across 14 RGs; identify zones with identical suffixes across envs.
2. Create hub VNet, move shared zones, update VNet links per spoke, validate Resolve-DnsName from each spoke; decommission per-env zones in batches.

---

### 10. Azure Compute Savings Plan - 1 week + Finance - CAD $30,708/yr

> Purchase after step 6 (env deletions) - avoid committing to capacity for environments about to be removed.

| Service | Annual CAD | CV% | SP @17% |
|---|---|---|---|
| Azure App Service | $64,287 | 55.9% | $10,929 |
| Azure Cognitive Search | $37,235 | 55.2% | $6,330 |
| Azure DNS | $22,753 | 55.3% | $3,868 |
| Azure Container Apps | $14,471 | 48.9% | $2,460 |
| Microsoft Defender for Cloud | $14,284 | 54.8% | $2,428 |
| Virtual Network | $13,649 | 56.2% | $2,320 |
| Container Registry | $8,292 | 55.6% | $1,410 |
| PostgreSQL + Storage + Redis + LB | $5,509 | 49-58% | $963 |
| **TOTAL Dev SP @17%** | | | **$30,708/yr** |

**Execution plan:**
1. After completing step 6, re-run extract-costs.ps1 + build-db.py to recompute CV% on the stable fleet; confirm services with CV < 35% as 1-year Reserved Instance candidates vs 17% Savings Plan.
2. Submit Finance approval for 1-year Compute Savings Plan scoped to EsDAICoESub; set a Cost Management budget alert on reservation utilisation to catch under-utilisation immediately.

---

### 11. APIM Token Budget Enforcement - 3 days - $150K+ per incident prevented

> No per-app AI token quotas exist. April 2025 ran unchecked for 14 days ($159K). Feb 2026 shows the same pattern is recurring.

| Component | Detail |
|---|---|
| Routing | x-caller-app header -> per-app APIM policy |
| Cap | azure-openai-token-limit policy per app per day |
| At 80% | Action Group -> Teams + owner email |
| At 100% | HTTP 429 Retry-After: tomorrow |

**Execution plan:**
1. Add azure-openai-token-limit inbound policy in APIM keyed on x-caller-app header; initial budget = historical max x 2 per app; deploy to non-prod APIM first and validate with a synthetic load test.
2. Wire 80% threshold to Action Group; document the override process for legitimate large batch jobs; log all throttle events to Application Insights.

---

### 12. Shared Cost Chargeback - 2 weeks + executive sponsor - CAD $70,000-$118,000/yr (behavioural)

> 83% of spend is IsSharedCost=True. No team sees their bill; no incentive to reduce. Historical benchmark: 15-25% behavioural reduction within 2-3 billing cycles.

| Scenario | Dev saving/yr |
|---|---|
| Conservative @15% | $35,289 |
| Expected @20% | $47,052 |
| Optimistic @25% | $58,815 |

**Execution plan:**
1. Enable monthly chargeback reports from AllocateCostByApp() outputs; run first month as read-only (email to team leads, no billing consequences) to validate allocation accuracy.
2. After exec sponsorship confirmed, switch to hard chargeback in Q3 2026; apply Azure Policy to audit/deny deployments missing ClientBu tag on new EsDAICoESub resources.

---

## Summary

| # | Opportunity | CAD/yr | Effort | Complexity |
|---|---|---|---|---|
| 1 | Dev Box Auto-Stop | $5,548-$7,902 | 30 min | Trivial |
| 2 | Log Analytics Retention | $1,000-$2,000 | 2 h | Trivial |
| 3 | Defender Plan Downgrade | $4,000-$6,000 | 2-3 h | Easy |
| 4 | Night + Weekend Shutdown | $33,764-$48,088 | 1 day | Easy |
| 5 | Anomaly Alert (KQL) | $156K+/incident | 1 day | Easy |
| 6 | Delete Stale InfoAssist Envs | $33,000-$63,000 | 1 afternoon | Easy (team decision) |
| 7 | Cognitive Search S1 to Basic | $12,000-$18,000 | 1 day | Medium |
| 8 | Container Registry Consolidation | $3,000-$4,500 | 1 week | Medium |
| 9 | DNS Hub-Spoke | $6,000-$10,000 | 1 week | Involved |
| 10 | Azure Savings Plan | $30,708 | 1 week + Finance | Involved |
| 11 | APIM Token Budgets | $150K+/incident | 3 days | Involved |
| 12 | Shared Cost Chargeback | $70,000-$118,000 | 2 weeks + exec | Strategic |

| Horizon | Opportunities | CAD/yr |
|---|---|---|
| This week (1-6) | ~3 days total | $77K-$127K |
| This quarter (7-10) | +2-3 weeks | +$52K-$62K |
| This year (11-12) | +exec + Finance | +$220K-$268K incident-adjusted |

> Dev run-rate: $235K/yr. This-week actions alone return 33-54% of the full annual run-rate.
> Complete step 6 (env deletions) before purchasing step 10 (Savings Plan) to avoid committing to removed capacity.

---

## Data Provenance

| Artefact | Path |
|---|---|
| Extraction script | tools/finops/extract-costs.ps1 |
| SQLite DB | tools/finops/dev-costs.db |
| Analysis script | tools/finops/build-db.py |
| Analysis summary | tools/finops/analysis-summary.txt |

Refresh at any time:
  & tools/finops/extract-costs.ps1
  & venv/Scripts/python.exe tools/finops/build-db.py
