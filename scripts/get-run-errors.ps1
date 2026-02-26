# Fetch activity-level errors from a failed ADF pipeline run
$t = (az account get-access-token --resource "https://management.azure.com" -o json | ConvertFrom-Json).accessToken
$sub = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$rg  = "EsDAICoE-Sandbox"
$adf = "marco-sandbox-finops-adf"

# Use the last known failed runId from backfill
$runId = "66efcafc-f171-47b3-b6a5-8db926f1beb0"

$uri = "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg" +
       "/providers/Microsoft.DataFactory/factories/$adf" +
       "/pipelineruns/$runId/queryActivityruns?api-version=2018-06-01"

$body = '{"lastUpdatedAfter":"2026-02-26T08:00:00Z","lastUpdatedBefore":"2026-02-26T10:00:00Z"}'

$resp = Invoke-RestMethod -Method POST -Uri $uri `
    -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
    -Body $body

foreach ($act in $resp.value) {
    Write-Host "=== $($act.activityName) | $($act.activityType) | $($act.status) ==="
    if ($act.error) {
        Write-Host "  Code   : $($act.error.errorCode)"
        Write-Host "  Message: $($act.error.message)"
    }
    if ($act.output) {
        Write-Host "  Output : $($act.output | ConvertTo-Json -Compress)"
    }
}
