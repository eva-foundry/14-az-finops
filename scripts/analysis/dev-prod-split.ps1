param(
    [string]$cluster = "https://marcofinopsadx.canadacentral.kusto.windows.net",
    [string]$db      = "finopsdb"
)
$t = (az account get-access-token --resource $cluster --query accessToken -o tsv 2>$null)
function Q([string]$kql) {
    (Invoke-RestMethod -Method POST `
        -Uri "$cluster/v1/rest/query" `
        -Headers @{ Authorization="Bearer $t"; "Content-Type"="application/json" } `
        -Body (@{db=$db;csl=$kql}|ConvertTo-Json -Compress -Depth 10)
    ).Tables[0]
}

# Anomaly exclusion fragment reused in all queries
$X = 'not(MeterCategory == "Foundry Tools" and format_datetime(Date,"yyyy-MM")=="2025-04") and not(MeterCategory == "Foundry Models" and MeterName has "Provisioned Managed" and isempty(ResourceGroup))'

# ── 1. HEADLINE TOTALS ─────────────────────────────────────────────────────
$r=(Q "raw_costs | where $X | summarize Cost=round(sum(CostInBillingCurrency),2), Rows=count() by SubscriptionName | order by Cost desc")
Write-Host "`n════════════════════════════════════════════════════"
Write-Host " HEADLINE TOTALS  (anomaly-free, 12-month run-rate)"
Write-Host "════════════════════════════════════════════════════"
$grandTotal = 0
$r.Rows | % {
    "  {0,-20}  CAD {1,10}   ({2} rows)" -f $_[0],$_[1],$_[2]
    $grandTotal += [double]$_[1]
}
"  {'TOTAL',-20}  CAD {0,10}" -f [math]::Round($grandTotal,2)

# ── 2. DEV — breakdown by category ────────────────────────────────────────
$rDev=(Q "raw_costs | where $X and SubscriptionName=='EsDAICoESub' | summarize Cost=round(sum(CostInBillingCurrency),2) by MeterCategory | order by Cost desc")
Write-Host "`n────────────────────────────────────────────────────"
Write-Host " DEV  (EsDAICoESub)  — by service category"
Write-Host "────────────────────────────────────────────────────"
$devTotal=0; $rDev.Rows | % { "  {0,-45}  CAD {1,9}" -f $_[0],$_[1]; $devTotal+=[double]$_[1] }
"  {'TOTAL DEV',-45}  CAD {0,9}" -f [math]::Round($devTotal,2)

# ── 3. PROD — breakdown by category ───────────────────────────────────────
$rProd=(Q "raw_costs | where $X and SubscriptionName=='EsPAICoESub' | summarize Cost=round(CostInBillingCurrency,2) by MeterCategory | order by Cost desc" 2>&1)
$rProd=(Q "raw_costs | where $X and SubscriptionName=='EsPAICoESub' | summarize Cost=round(sum(CostInBillingCurrency),2) by MeterCategory | order by Cost desc")
Write-Host "`n────────────────────────────────────────────────────"
Write-Host " PROD (EsPAICoESub) — by service category"
Write-Host "────────────────────────────────────────────────────"
$prodTotal=0; $rProd.Rows | % { "  {0,-45}  CAD {1,9}" -f $_[0],$_[1]; $prodTotal+=[double]$_[1] }
"  {'TOTAL PROD',-45}  CAD {0,9}" -f [math]::Round($prodTotal,2)

# ── 4. DEV — stoppable compute detail (App Service, Container Apps, VMs, Dev Box) ─
$rComp=(Q "raw_costs | where $X and SubscriptionName=='EsDAICoESub' and MeterCategory in ('Azure App Service','Azure Container Apps','Virtual Machines','Microsoft Dev Box','Azure Container Instances','Azure Kubernetes Service') | summarize Cost=round(sum(CostInBillingCurrency),2) by MeterCategory, MeterSubCategory, ResourceGroup | order by Cost desc")
Write-Host "`n────────────────────────────────────────────────────"
Write-Host " DEV STOPPABLE COMPUTE (night-shutdown candidates)"
Write-Host "────────────────────────────────────────────────────"
$compTotal=0; $rComp.Rows | % {
    "  {0,-35} {1,-40} CAD {2,8}" -f $_[0],$_[1],$_[2]
    $compTotal+=[double]$_[2]
}
$saving8h=[math]::Round($compTotal*8/24,2)
$saving=  [math]::Round($compTotal*0.33,2)
"  {'TOTAL DEV COMPUTE',-76}  CAD {0,8}" -f [math]::Round($compTotal,2)
"  Night-shutdown saving (8h off / 24h = 33%):  CAD {0,8}/year" -f $saving

# ── 5. Dev Box detail ──────────────────────────────────────────────────────
$rDB=(Q "raw_costs | where $X and MeterCategory=='Microsoft Dev Box' | summarize Cost=round(sum(CostInBillingCurrency),2) by MeterSubCategory, ResourceGroup | order by Cost desc")
Write-Host "`n────────────────────────────────────────────────────"
Write-Host " DEV BOX detail"
Write-Host "────────────────────────────────────────────────────"
$rDB.Rows | % { "  {0,-35} rg={1,-35} CAD {2,8}" -f $_[0],$_[1],$_[2] }

# ── 6. Cognitive Search — how many instances per env ──────────────────────
$rCS=(Q "raw_costs | where $X and (MeterCategory has 'Cognitive Search' or MeterCategory has 'Search') | summarize Cost=round(sum(CostInBillingCurrency),2) by SubscriptionName, MeterSubCategory, ResourceGroup | order by SubscriptionName asc, Cost desc")
Write-Host "`n────────────────────────────────────────────────────"
Write-Host " COGNITIVE SEARCH — instances (Standard S1=\$259 CAD/mo each)"
Write-Host "────────────────────────────────────────────────────"
$rCS.Rows | % { "  {0,-15} {1,-25} rg={2,-45} CAD {3,8}" -f $_[0],$_[1],$_[2],$_[3] }

# ── 7. Defender for Cloud — always-on tax ─────────────────────────────────
$rDef=(Q "raw_costs | where $X and MeterCategory=='Microsoft Defender for Cloud' | summarize Cost=round(sum(CostInBillingCurrency),2) by SubscriptionName, MeterSubCategory | order by SubscriptionName, Cost desc")
Write-Host "`n────────────────────────────────────────────────────"
Write-Host " DEFENDER FOR CLOUD"
Write-Host "────────────────────────────────────────────────────"
$rDef.Rows | % { "  {0,-15} {1,-45} CAD {2,8}" -f $_[0],$_[1],$_[2] }

# ── 8. Log Analytics per env ───────────────────────────────────────────────
$rLA=(Q "raw_costs | where $X and MeterCategory=='Log Analytics' | summarize Cost=round(sum(CostInBillingCurrency),2) by SubscriptionName, MeterSubCategory, ResourceGroup | order by SubscriptionName, Cost desc")
Write-Host "`n────────────────────────────────────────────────────"
Write-Host " LOG ANALYTICS"
Write-Host "────────────────────────────────────────────────────"
$rLA.Rows | % { "  {0,-15} {1,-30} rg={2,-35} CAD {3,8}" -f $_[0],$_[1],$_[2],$_[3] }

Write-Host "`n════ DONE ════"
