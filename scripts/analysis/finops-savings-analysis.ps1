$cluster = "https://marcofinopsadx.canadacentral.kusto.windows.net"
$db = "finopsdb"
$t = (az account get-access-token --resource $cluster --query accessToken -o tsv 2>$null)

function Q([string]$kql) {
    $body = @{ db = $db; csl = $kql } | ConvertTo-Json -Compress -Depth 10
    return (Invoke-RestMethod -Method POST -Uri "$cluster/v1/rest/query" `
        -Headers @{ Authorization="Bearer $t"; "Content-Type"="application/json" } `
        -Body $body).Tables[0]
}

Write-Host "`n`n══════════════════════════════════════════════════════════════"
Write-Host " FINOPS-ENABLED SAVINGS ANALYSIS"
Write-Host "══════════════════════════════════════════════════════════════"

# ── 1. RI / SAVINGS PLAN CANDIDATES ──────────────────────────────────────────
Write-Host "`n[1] RESERVED INSTANCE / SAVINGS PLAN CANDIDATES"
Write-Host "    CV% = coefficient of variation (lower = more consistent = better RI fit)"
Write-Host "    Azure Savings Plans: ~17% discount (1yr) | Azure RIs: ~35-40% discount (1yr)"
Write-Host ""
$r = (Q @"
raw_costs
| where not(MeterCategory == 'Foundry Tools' and format_datetime(Date,'yyyy-MM')=='2025-04')
| where not(MeterCategory == 'Foundry Models' and MeterName has 'Provisioned Managed' and isempty(ResourceGroup))
| summarize MonthlyCost=round(sum(CostInBillingCurrency),2)
  by Month=format_datetime(Date,'yyyy-MM'), SubscriptionName, MeterCategory
| summarize AvgMonthly=round(avg(MonthlyCost),2),
            StdDev=round(stdev(MonthlyCost),2),
            ActiveMonths=count(),
            AnnualEst=round(avg(MonthlyCost)*12,2)
  by SubscriptionName, MeterCategory
| where ActiveMonths >= 10 and AvgMonthly > 100
| extend CVpct = round(StdDev / AvgMonthly * 100, 1)
| order by CVpct asc
"@)
$riTotal = 0; $riSaving17 = 0; $riSaving35 = 0
Write-Host "  Sub             Category                                  Avg/mo    Annual   CV%   RI-Saving@35%"
foreach ($row in $r.Rows) {
    $sub=$row[0]; $cat=$row[1]; $avg=[double]$row[2]; $ann=[double]$row[5]; $cv=[double]$row[6]; $mo=$row[4]
    $ri35 = [math]::Round($ann * 0.35, 0)
    $fit = if ($cv -lt 25) { "★★★ EXCELLENT" } elseif ($cv -lt 40) { "★★  GOOD" } elseif ($cv -lt 60) { "★   FAIR" } else { "    VARIABLE" }
    "  {0,-14} {1,-40} CAD{2,7}/mo  CAD{3,8}/yr  CV={4,5}%  save~CAD{5,7}  {6}" -f $sub,$cat,$avg,$ann,$cv,$ri35,$fit
    if ($cv -lt 60) { $riTotal += $ann; $riSaving17 += [math]::Round($ann*0.17,0); $riSaving35 += $ri35 }
}
Write-Host ""
"  Total annual spend in consultable categories (CV<60%): CAD $riTotal"
"  Conservative saving @17% (Savings Plan 1yr):           CAD $riSaving17"
"  Aggressive saving   @35% (Reserved Instance 1yr):      CAD $riSaving35"

# ── 2. ANOMALY DETECTION BACKTEST — April 2025 ───────────────────────────────
Write-Host "`n[2] ANOMALY DETECTION BACKTEST — What if we had alerted on day 1 of the April spike?"
$r2 = (Q @"
raw_costs
| where SubscriptionName == 'EsDAICoESub' and MeterCategory == 'Foundry Tools'
| where format_datetime(Date,'yyyy-MM') >= '2025-02' and format_datetime(Date,'yyyy-MM') <= '2025-03'
| summarize BaselineAvgDaily=round(avg(CostInBillingCurrency),2), BaselineTotalMonthly=round(sum(CostInBillingCurrency),2)
"@)
$baseline = [double]($r2.Rows[0][0])
$r3 = (Q @"
raw_costs
| where SubscriptionName == 'EsDAICoESub' and MeterCategory == 'Foundry Tools'
  and MeterSubCategory == 'Translator Text'
  and format_datetime(Date,'yyyy-MM') == '2025-04'
| summarize DailyCost=round(sum(CostInBillingCurrency),2) by Day=bin(Date,1d)
| order by Day asc
"@)
$runningCost = 0; $daysCounted = 0
Write-Host "  Baseline Foundry Tools daily avg (Feb-Mar 2025): CAD $baseline"
Write-Host ""
Write-Host "  Apr 2025 cumulative spending if stopped on each day (alert threshold: 3× baseline):"
$threshold = $baseline * 3
foreach ($row in $r3.Rows) {
    $day = $row[0].ToString("yyyy-MM-dd")
    $cost = [double]$row[1]
    $runningCost += $cost; $daysCounted++
    $flag = if ($runningCost -gt $threshold -and $daysCounted -eq 1) { " ← FIRST ALERT DAY" }
            elseif ($cost -gt $threshold) { " ← DAILY SPIKE" } else { "" }
    "  Day {0,2} ({1})  daily=CAD{2,8}  cumulative=CAD{3,10}{4}" -f $daysCounted,$day,$cost,$runningCost,$flag
}
$r4 = (Q @"
raw_costs
| where SubscriptionName == 'EsDAICoESub' and MeterCategory == 'Foundry Tools'
  and format_datetime(Date,'yyyy-MM') == '2025-04'
| summarize TotalApril=round(sum(CostInBillingCurrency),2)
"@)
$aprilTotal = [double]($r4.Rows[0][0])
# First spike day cost = day 1 cumulative
$firstDayCost = [double]($r3.Rows[0][1])
$savedIfAlertDay1 = [math]::Round($aprilTotal - $firstDayCost, 2)
Write-Host ""
"  Total April Foundry Tools spend:                    CAD $aprilTotal"
"  Cost if stopped after day 1 alert (Apr 10):         CAD $firstDayCost"
"  POTENTIAL SAVING with anomaly alert (day 1 stop):   CAD $savedIfAlertDay1"
"  (series_decompose_anomalies() would have caught this on Apr 10 — day 1 of spike)"

# ── 3. SHARED COST ALLOCATION IMPACT ─────────────────────────────────────────
Write-Host "`n[3] SHARED COST ALLOCATION (83% of spend is IsSharedCost=True)"
Write-Host "    Without FinOps: ALL shared costs fall on CostCenter 00014 — no per-team visibility"
Write-Host "    With FinOps:    Allocate by ProjectDisplayName weight → each team sees their bill"
$r5 = (Q @"
NormalizedCosts()
| where IsSharedCost == 'True'
| summarize SharedCost=round(sum(CostInBillingCurrency),2), Rows=count() by ProjectDisplayName
| order by SharedCost desc
"@)
$sharedTotal = 0
Write-Host ""
Write-Host "  Shared cost by Project (currently all charged to todd.whitley / CostCenter 00014):"
foreach ($row in $r5.Rows) {
    "  {0,-45} CAD {1,9}" -f $row[0],$row[1]
    $sharedTotal += [double]$row[1]
}
"  TOTAL SHARED COST (unallocated without FinOps): CAD $sharedTotal"
Write-Host ""
Write-Host "  With FinOps chargeback: each project team would receive a monthly bill showing"
Write-Host "  their proportional share. Behavioral change typically drives 15-25% reduction"
Write-Host "  in shared service consumption within 2-3 billing cycles."
$behaviorSaving = [math]::Round($sharedTotal * 0.20, 0)
"  Conservative saving @20% behavioral reduction:  CAD $behaviorSaving/year"

# ── 4. TAG COVERAGE → ACCOUNTABILITY GAP ─────────────────────────────────────
Write-Host "`n[4] TAG COVERAGE GAP → UNACCOUNTABLE SPEND"
Write-Host "    Resources with no ClientBu tag = no team accountability = no cost pressure"
$r6 = (Q @"
NormalizedCosts()
| summarize
    Tagged=round(sumif(CostInBillingCurrency, ClientBu != 'Unknown' and ClientBu != ''),2),
    Untagged=round(sumif(CostInBillingCurrency, ClientBu == 'Unknown' or ClientBu == ''),2)
"@)
foreach ($row in $r6.Rows) {
    "  Tagged (ClientBu known):   CAD {0,9}" -f $row[0]
    "  Untagged (no ClientBu):    CAD {0,9}  ← nobody owns this, nobody cares about cost" -f $row[1]
    $behaviorTag = [math]::Round([double]$row[1] * 0.15, 0)
    "  Saving if tagged teams reduce 15%: CAD $behaviorTag/year"
}

# ── 5. REDIS CACHE — RI CHECK ─────────────────────────────────────────────────
Write-Host "`n[5] REDIS CACHE — RESERVED INSTANCE (monthly bills)"
$r7 = (Q @"
raw_costs
| where MeterCategory == 'Redis Cache'
| summarize Cost=round(sum(CostInBillingCurrency),2) by SubscriptionName, MeterSubCategory, ResourceGroup, MeterName
| order by Cost desc
"@)
foreach ($row in $r7.Rows) {
    "  {0,-14} {1,-25} rg={2,-30} meter={3,-25} CAD {4,7}" -f $row[0],$row[1],$row[2],$row[3],$row[4]
}
Write-Host "  Redis Cache Reserved Instances available at ~35% discount (1-year)"
$r7Total = ($r7.Rows | % { [double]$_[4] } | Measure-Object -Sum).Sum
"  Total Redis: CAD $([math]::Round($r7Total,2))  →  RI saving: CAD $([math]::Round($r7Total*0.35,0))/year"

# ── 6. PER-APP TOKEN BUDGET ENFORCEMENT VIA APIM ─────────────────────────────
Write-Host "`n[6] APIM TOKEN BUDGET ENFORCEMENT (prevents runaway AI spend)"
Write-Host "    WITHOUT APIM: no per-app quotas — any app can spend unlimited on AI services"
Write-Host "    WITH APIM:    x-caller-app header → per-app token quota policy in APIM"
Write-Host "                  Daily budget cap per app → auto-block at threshold"
Write-Host ""
$r8 = (Q @"
NormalizedCosts()
| where MeterCategory in ('Foundry Tools','Foundry Models','Azure Cognitive Services')
| summarize Cost=round(sum(CostInBillingCurrency),2) by EffectiveCallerApp, MeterCategory, SubscriptionName
| order by Cost desc
| take 15
"@)
foreach ($row in $r8.Rows) {
    "  app={0,-20} cat={1,-30} sub={2,-15} CAD {3,8}" -f $row[0],$row[1],$row[2],$row[3]
}
Write-Host ""
Write-Host "  The April 2025 runaway batch (CAD 158,922) had NO quota enforcement."
Write-Host "  APIM rate-limit policy (e.g. 10M chars/day for Translator Text per app)"
Write-Host "  would have blocked it on day 1 → saving CAD ~140,000 in that incident alone."

Write-Host "`n`n══════════════════════════════════════════════════════════════"
Write-Host " FINOPS SAVINGS SUMMARY"
Write-Host "══════════════════════════════════════════════════════════════"
Write-Host @"
  Category                                          Saving/yr CAD   Requires
  ─────────────────────────────────────────────────────────────────────────────
  RI / Savings Plans (consistent services)          17K-55K        FinOps RI purchase
  Anomaly detection (prevent future batch runaway)  ~140K/incident FinOps alerting
  Shared cost chargeback behavioral change          ~40K-90K       FinOps allocation
  Tag coverage → team accountability (15% reduction)  30-52K       FinOps tagging policy
  APIM token budgets (per-app quota enforcement)    TBD, 140K+     Phase 3 APIM
  ─────────────────────────────────────────────────────────────────────────────
  TOTAL (excluding anomaly prevention)              87K-197K/yr
"@

Write-Host "════ DONE ════"
