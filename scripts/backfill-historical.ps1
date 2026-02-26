# backfill-historical.ps1
# Triggers ADF pipeline ingest-costs-to-adx for every existing .csv.gz in raw/costs/
# Usage:
#   .\backfill-historical.ps1              # run all 28 blobs
#   .\backfill-historical.ps1 -WhatIf      # preview only
#   .\backfill-historical.ps1 -DelaySeconds 30   # slow down between triggers

[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$DelaySeconds     = 15,
    [string]$StorageAccount = "marcosandboxfinopshub",
    [string]$Container      = "raw",
    [string]$BlobPrefix     = "costs/",
    [string]$ResourceGroup  = "EsDAICoE-Sandbox",
    [string]$AdfName        = "marco-sandbox-finops-adf",
    [string]$PipelineName   = "ingest-costs-to-adx",
    [string]$SubscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== FinOps Backfill ===" -ForegroundColor Cyan
Write-Host "Storage : $StorageAccount/$Container/$BlobPrefix"
Write-Host "Pipeline: $AdfName / $PipelineName"
Write-Host ""

# Set subscription context
az account set --subscription $SubscriptionId

# Acquire ARM token once (reuse for all calls)
Write-Host "Acquiring ARM token..." -ForegroundColor Yellow
$tokenJson = az account get-access-token --resource "https://management.azure.com" -o json | ConvertFrom-Json
$token = $tokenJson.accessToken
Write-Host "Token acquired (expires $($tokenJson.expiresOn))" -ForegroundColor Green
Write-Host ""

# List all .csv.gz blobs under raw/costs/
Write-Host "Listing blobs..." -ForegroundColor Yellow
$blobs = az storage blob list `
    --account-name $StorageAccount `
    --container-name $Container `
    --prefix $BlobPrefix `
    --query "[?ends_with(name, '.csv.gz')].name" `
    --auth-mode login `
    -o json 2>&1 | ConvertFrom-Json

if (-not $blobs -or $blobs.Count -eq 0) {
    Write-Host "No blobs found — check storage account access." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($blobs.Count) blobs to backfill.`n" -ForegroundColor Green

$ok    = 0
$fail  = 0
$total = $blobs.Count

foreach ($blobName in $blobs) {
    $idx     = $blobs.IndexOf($blobName) + 1
    $fullUrl = "https://$StorageAccount.blob.core.windows.net/$Container/$blobName"

    Write-Host "[$idx/$total] $blobName" -ForegroundColor Yellow

    if ($PSCmdlet.ShouldProcess($blobName, "Trigger ADF pipeline")) {
        # Derive subscriptionTag from blob path (EsDAICoESub or EsPAICoESub)
        $subTag = if ($blobName -match "(Es[A-Za-z]+CoESub)") { $Matches[1] } else { "Unknown" }

        # Build request body
        $body = @{
            blobUrl         = $fullUrl
            containerName   = $Container
            subscriptionTag = $subTag
        }

        # ADF createRun REST API — Invoke-RestMethod avoids az extension / pip issues
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup" +
               "/providers/Microsoft.DataFactory/factories/$AdfName/pipelines/$PipelineName" +
               "/createRun?api-version=2018-06-01"

        try {
            $response = Invoke-RestMethod -Method Post -Uri $uri `
                -Headers @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" } `
                -Body ($body | ConvertTo-Json -Compress)

            Write-Host "  runId: $($response.runId)" -ForegroundColor Green
            $ok++
        } catch {
            Write-Host "  [FAIL] $($_.Exception.Message)" -ForegroundColor Red
            $fail++
        }

        if ($idx -lt $total) {
            Write-Host "  Waiting ${DelaySeconds}s before next trigger..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

Write-Host ""
Write-Host "=== Backfill Complete ===" -ForegroundColor Cyan
Write-Host "  Triggered : $ok"
Write-Host "  Failed    : $fail"
Write-Host ""
Write-Host "Monitor runs at:"
Write-Host "  https://adf.azure.com/en/monitoring/pipelineruns?factory=%2Fsubscriptions%2F$SubscriptionId%2FresourceGroups%2F$ResourceGroup%2Fproviders%2FMicrosoft.DataFactory%2Ffactories%2F$AdfName"
