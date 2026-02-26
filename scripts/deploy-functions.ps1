$t       = (az account get-access-token --resource "https://marcofinopsadx.canadacentral.kusto.windows.net" -o json | ConvertFrom-Json).accessToken
$cluster = "https://marcofinopsadx.canadacentral.kusto.windows.net"
$db      = "finopsdb"
$root    = "c:\eva-foundry-local\14-az-finops\scripts\kql"

foreach ($f in @("08-normalized-costs-function.kql", "09-allocate-cost-function.kql")) {
    # Strip // comment lines — ADX mgmt endpoint rejects files with comment-only headers
    $csl  = (Get-Content "$root\$f" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
    $body = @{ db = $db; csl = $csl } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod -Method POST -Uri "$cluster/v1/rest/mgmt" `
            -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
            -Body $body | Out-Null
        Write-Host "[OK]   $f" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] $f : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Smoke test: NormalizedCosts with the new fallback columns (v2 — CanonicalEnvironment)
Write-Host "`nSmoke test — Pre-APIM rows (v2 columns):" -ForegroundColor Cyan
$q = @"
NormalizedCosts()
| where MeterCategory has 'API Management'
| project Date, EffectiveCallerApp, EffectiveCostCenter, CanonicalEnvironment,
          SscBillingCode, IsSharedCost, CostInBillingCurrency
| take 5
"@
$body2 = @{ db = $db; csl = $q } | ConvertTo-Json -Compress
$r = Invoke-RestMethod -Method POST -Uri "$cluster/v1/rest/query" `
    -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
    -Body $body2
$cols = $r.Tables[0].Columns | ForEach-Object { $_.ColumnName }
$r.Tables[0].Rows | ForEach-Object {
    $row = $_; $out = @{}; for ($i=0; $i -lt $cols.Count; $i++) { $out[$cols[$i]] = $row[$i] }
    Write-Host ($out | ConvertTo-Json -Compress)
}
