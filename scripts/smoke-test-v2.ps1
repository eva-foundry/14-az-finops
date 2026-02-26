# smoke-test-v2.ps1  —  NormalizedCosts() v2 validation
# Runs 6 targeted queries to evidence the tag bug-fix and new ESDC dimensions.
# All output also saved to ../evidence/smoke-test-v2-<DATE>.json

$cluster = "https://marcofinopsadx.canadacentral.kusto.windows.net"
$db      = "finopsdb"

Write-Host "Acquiring ADX token..." -ForegroundColor DarkGray
$t = (az account get-access-token --resource $cluster -o json | ConvertFrom-Json).accessToken

$evidenceDir = Join-Path $PSScriptRoot "..\evidence"
if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir | Out-Null }
$outFile = Join-Path $evidenceDir ("smoke-test-v2-" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".json")

$results = [ordered]@{}

function Invoke-KQL($label, $query) {
    Write-Host "`n[$label]" -ForegroundColor Cyan
    $body = @{ db = $db; csl = $query } | ConvertTo-Json -Compress
    try {
        $r    = Invoke-RestMethod -Method POST -Uri "$cluster/v1/rest/query" `
                    -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
                    -Body $body
        $cols = $r.Tables[0].Columns | ForEach-Object { $_.ColumnName }
        $rows = $r.Tables[0].Rows | ForEach-Object {
            $row = $_; $out = [ordered]@{}
            for ($i = 0; $i -lt $cols.Count; $i++) { $out[$cols[$i]] = $row[$i] }
            $out
        }
        foreach ($row in $rows) { Write-Host ($row | ConvertTo-Json -Compress) }
        $script:results[$label] = $rows
    } catch {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        $script:results[$label] = "ERROR: $($_.Exception.Message)"
    }
}

# ── Test 1: Total rows + tagged rows (fix coverage) ──────────────────────────
Invoke-KQL "T1_RowCount" @"
NormalizedCosts()
| summarize
    TotalRows       = count(),
    TaggedRows      = countif(isnotempty(SscBillingCode) or isnotempty(FinancialAuthority)),
    SscStandardRows = countif(isnotempty(FinancialAuthority))
"@

# ── Test 2: CanonicalEnvironment distribution (was all null before fix) ───────
Invoke-KQL "T2_CanonicalEnvironment" @"
NormalizedCosts()
| summarize Rows = count() by CanonicalEnvironment
| order by Rows desc
"@

# ── Test 3: SscBillingCode distribution ──────────────────────────────────────
Invoke-KQL "T3_SscBillingCode" @"
NormalizedCosts()
| summarize Rows = count(), TotalCost = round(sum(CostInBillingCurrency), 2)
  by SscBillingCode
| order by TotalCost desc
"@

# ── Test 4: IsSharedCost split ────────────────────────────────────────────────
Invoke-KQL "T4_IsSharedCost" @"
NormalizedCosts()
| summarize Rows = count(), TotalCost = round(sum(CostInBillingCurrency), 2)
  by IsSharedCost
"@

# ── Test 5: EffectiveCostCenter distribution ─────────────────────────────────
Invoke-KQL "T5_EffectiveCostCenter" @"
NormalizedCosts()
| summarize Rows = count(), TotalCost = round(sum(CostInBillingCurrency), 2)
  by EffectiveCostCenter
| order by TotalCost desc
"@

# ── Test 6: AllocateCostByApp sanity check ────────────────────────────────────
Invoke-KQL "T6_AllocateCostByApp" @"
AllocateCostByApp()
| summarize Rows = count(), TotalCost = round(sum(AllocatedCost), 2)
  by CallerApp, CostCenter, Environment, AttributionSource
| order by TotalCost desc
| take 10
"@

# ── Save evidence ─────────────────────────────────────────────────────────────
$results | ConvertTo-Json -Depth 10 | Out-File $outFile -Encoding UTF8
Write-Host "`nEvidence saved: $outFile" -ForegroundColor Green
