# redeploy-adf-dataset-pipeline.ps1
# Redeploys the fixed ds_blob_cost_csv dataset and ingest-costs-to-adx pipeline

param(
    [string]$ResourceGroup  = "EsDAICoE-Sandbox",
    [string]$AdfName        = "marco-sandbox-finops-adf",
    [string]$SubscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
)

$t    = (az account get-access-token --resource "https://management.azure.com" -o json | ConvertFrom-Json).accessToken
$base = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup" +
        "/providers/Microsoft.DataFactory/factories/$AdfName"
$hdrs = @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" }
$root = "$PSScriptRoot"

function Deploy($type, $name, $file) {
    $uri  = "$base/$type/$name`?api-version=2018-06-01"
    $body = Get-Content $file -Raw | ConvertFrom-Json
    # Strip top-level name/type/etag — only send properties
    $payload = @{ properties = $body.properties } | ConvertTo-Json -Depth 20 -Compress
    try {
        $r = Invoke-RestMethod -Method PUT -Uri $uri -Headers $hdrs -Body $payload
        Write-Host "  [OK] $type/$name" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $type/$name : $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

Write-Host "=== Redeploying fixed ADF artefacts ===" -ForegroundColor Cyan

Deploy "datasets"  "ds_blob_cost_csv"       "$root\adf\datasets\ds_blob_cost_csv.json"
Deploy "pipelines" "ingest-costs-to-adx"    "$root\adf\pipelines\ingest-costs-to-adx.json"

Write-Host ""
Write-Host "Done. Test one blob:" -ForegroundColor Cyan
Write-Host '  & ".\backfill-historical.ps1" -DelaySeconds 0 (first blob only by modifying script)'
