param(
    [string]$cluster = "https://marcofinopsadx.canadacentral.kusto.windows.net",
    [string]$db = "finopsdb"
)

$t = (az account get-access-token --resource $cluster --query accessToken -o tsv 2>$null)
if (-not $t) { throw "ADX token failed" }
Write-Host "Token OK ($($t.Length) chars)"

function Kql([string]$q) {
    $body = @{ db = $db; csl = $q } | ConvertTo-Json -Compress -Depth 10
    $resp = Invoke-RestMethod -Method POST -Uri "$cluster/v1/rest/query" `
        -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
        -Body $body
    return $resp.Tables[0]
}

# ── FILTERS: exclude the two anomalies ────────────────────────────────────────
$anomalyFilter = @'
where not(MeterCategory == 'Foundry Tools' and format_datetime(Date,'yyyy-MM')=='2025-04')
| where not(MeterCategory == 'Foundry Models' and MeterName has 'Provisioned Managed' and isempty(ResourceGroup))
'@

# ── Q1: Clean totals by Env ───────────────────────────────────────────────────
$q1 = @"
raw_costs
| $anomalyFilter
| extend Env = case(
    Tags has '"fin_env":"dev"' or Tags has '"fin_env":"Dev"', 'Dev',
    Tags has '"fin_env":"prod"' or Tags has '"fin_env":"Prod"', 'Prod',
    Tags has '"fin_env":"stage"' or Tags has '"fin_env":"Stage"', 'Stage',
    SubscriptionName == 'EsPAICoESub', 'Prod-Untagged',
    'Dev-Untagged')
| summarize Cost=round(sum(CostInBillingCurrency),2), Rows=count() by Env
| order by Cost desc
"@
$r1 = Kql $q1
Write-Host "`n=== CLEAN TOTALS BY ENV (anomalies excluded) ==="
$r1.Rows | % { "  Env={0,-15} Cost=`${1,10} Rows={2}" -f $_[0], $_[1], $_[2] }

# ── Q2: Dev breakdown by MeterCategory ───────────────────────────────────────
$q2 = @"
raw_costs
| $anomalyFilter
| where Tags has '"fin_env":"dev"' or Tags has '"fin_env":"Dev"'
| summarize Cost=round(sum(CostInBillingCurrency),2), Rows=count() by MeterCategory
| order by Cost desc
"@
$r2 = Kql $q2
Write-Host "`n=== DEV CATEGORIES ==="
$r2.Rows | % { "  {0,-40} `${1,10}" -f $_[0], $_[1] }

# ── Q3: Prod breakdown by MeterCategory ──────────────────────────────────────
$q3 = @"
raw_costs
| $anomalyFilter
| where Tags has '"fin_env":"prod"' or Tags has '"fin_env":"Prod"' or SubscriptionName == 'EsPAICoESub'
| summarize Cost=round(sum(CostInBillingCurrency),2), Rows=count() by MeterCategory
| order by Cost desc
"@
$r3 = Kql $q3
Write-Host "`n=== PROD CATEGORIES ==="
$r3.Rows | % { "  {0,-40} `${1,10}" -f $_[0], $_[1] }

# ── Q4: Always-on compute in DEV (stoppable at night) ────────────────────────
# App Service, Container Apps, Virtual Machines, Dev Box, Container Instances
$q4 = @"
raw_costs
| $anomalyFilter
| where Tags has '"fin_env":"dev"' or Tags has '"fin_env":"Dev"'
| where MeterCategory in ('Azure App Service', 'Azure Container Apps', 'Virtual Machines',
                          'Microsoft Dev Box', 'Azure Container Instances',
                          'Azure Kubernetes Service', 'Azure Spring Apps')
  or (MeterCategory == 'Azure App Service' and MeterSubCategory has 'Linux')
| summarize Cost=round(sum(CostInBillingCurrency),2), Rows=count() by MeterCategory, MeterSubCategory, ResourceGroup, ResourceName
| order by Cost desc
| take 30
"@
$r4 = Kql $q4
Write-Host "`n=== DEV STOPPABLE COMPUTE (by resource) ==="
$r4.Rows | % { "  cat={0,-35} rg={1,-35} name={2,-30} cost=`${3}" -f $_[0], $_[2], $_[3], $_[4] }

# ── Q5: Dev compute total for night-shutdown calculation ─────────────────────
$q5 = @"
raw_costs
| $anomalyFilter
| where Tags has '"fin_env":"dev"' or Tags has '"fin_env":"Dev"'
| where MeterCategory in ('Azure App Service', 'Azure Container Apps', 'Virtual Machines',
                          'Microsoft Dev Box', 'Azure Container Instances',
                          'Azure Kubernetes Service', 'Azure Spring Apps')
| summarize TotalCompute=round(sum(CostInBillingCurrency),2), Rows=count() by MeterCategory
| order by TotalCompute desc
"@
$r5 = Kql $q5
Write-Host "`n=== DEV STOPPABLE COMPUTE TOTAL by category ==="
$total = 0
$r5.Rows | % { "  {0,-40} `${1}" -f $_[0], $_[1]; $total += [double]$_[1] }
Write-Host ("  TOTAL DEV COMPUTE: `${0:F2}" -f $total)
Write-Host ("  8h/24h shutdown savings (33%): `${0:F2}/year" -f ($total * 0.33))

# ── Q6: Dev Box costs (pure waste if no user logged in) ──────────────────────
$q6 = @"
raw_costs
| $anomalyFilter
| where MeterCategory == 'Microsoft Dev Box'
| summarize Cost=round(sum(CostInBillingCurrency),2), Rows=count() by MeterSubCategory, ResourceName, ResourceGroup
| order by Cost desc
"@
$r6 = Kql $q6
Write-Host "`n=== DEV BOX (high idle cost) ==="
$r6.Rows | % { "  sub={0,-30} rg={1,-30} cost=`${2}" -f $_[0], $_[2], $_[3] }

# ── Q7: Cognitive Search tiers in Dev (likely oversized) ─────────────────────
$q7 = @"
raw_costs
| $anomalyFilter
| where MeterCategory has 'Cognitive Search' or MeterCategory has 'Search'
| summarize Cost=round(sum(CostInBillingCurrency),2), Rows=count() by MeterCategory, MeterSubCategory, MeterName, ResourceName, ResourceGroup
| order by Cost desc | take 20
"@
$r7 = Kql $q7
Write-Host "`n=== COGNITIVE SEARCH (tier check) ==="
$r7.Rows | % { "  sub={0,-20} meter={1,-30} rg={2,-30} cost=`${3}" -f $_[1], $_[2], $_[4], $_[5] }

# ── Q8: Redundant/duplicate resources across envs (same meter in dev+prod) ───
$q8 = @"
raw_costs
| $anomalyFilter
| extend Env = case(
    Tags has '"fin_env":"dev"' or Tags has '"fin_env":"Dev"', 'Dev',
    Tags has '"fin_env":"prod"' or Tags has '"fin_env":"Prod"', 'Prod',
    Tags has '"fin_env":"stage"', 'Stage',
    SubscriptionName == 'EsPAICoESub', 'Prod',
    'Dev')
| summarize Cost=round(sum(CostInBillingCurrency),2) by Env, MeterCategory
| evaluate pivot(Env, sum(Cost))
| extend DevRatio = round(todouble(Dev) / (todouble(Dev) + todouble(Prod) + todouble(Stage)) * 100, 1)
| order by Dev desc
"@
$r8 = Kql $q8
Write-Host "`n=== DEV vs PROD RATIO by category ==="
$r8.Rows | % { 
    $cat = $_[0]; $dev = $_[1]; $prod = $_[2]; $stage = $_[3]; $ratio = $_[4]
    "  {0,-40} Dev=`${1,8} Prod=`${2,8} Stage=`${3,8} DevRatio={4}%" -f $cat, $dev, $prod, $stage, $ratio
}

# ── Q9: Spending outside business hours — approximate (hourly data not available,
#        but we can check if cost is uniform across months to flag always-on resources)
$q9 = @"
raw_costs
| $anomalyFilter
| where Tags has '"fin_env":"dev"' or Tags has '"fin_env":"Dev"'
| summarize MonthlyCost=round(sum(CostInBillingCurrency),2) by MonthKey=format_datetime(Date,'yyyy-MM'), MeterCategory
| summarize AvgMonthly=round(avg(MonthlyCost),2), StdDev=round(stdev(MonthlyCost),2), Months=count() by MeterCategory
| extend UniformScore = round(100.0 - (StdDev / (AvgMonthly + 0.01) * 100), 1)
| order by AvgMonthly desc | take 15
"@
$r9 = Kql $q9
Write-Host "`n=== ALWAYS-ON INDICATOR (low variance = always running) ==="
$r9.Rows | % { "  {0,-40} Avg/month=`${1,8} StdDev={2,8} Uniformity={3}%" -f $_[0], $_[1], $_[2], $_[3] }

Write-Host "`n=== DONE ==="
