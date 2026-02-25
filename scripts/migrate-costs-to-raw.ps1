#Requires -Version 5.1
<#
.SYNOPSIS
    Migrate cost export blobs from costs/ container to raw/ container.
    Preserves full blob path: costs/{name} -> raw/costs/{name}

.PARAMETER DryRun
    If set, only prints what would be copied without making changes.
#>
param(
    [string]$StorageAccount = "marcosandboxfinopshub",
    [string]$SourceContainer = "costs",
    [string]$DestinationContainer = "raw",
    [string]$DestinationPrefix = "costs",
    [switch]$DryRun
)

$mode = if ($DryRun) { "DRY-RUN" } else { "LIVE" }
Write-Host "================================================================"
Write-Host "  Cost Export Migration [$mode]"
Write-Host "  Source:      $SourceContainer/"
Write-Host "  Destination: $DestinationContainer/$DestinationPrefix/"
Write-Host "  Account:     $StorageAccount"
Write-Host "================================================================"

# Get all blobs
Write-Host "[INFO] Listing blobs in $SourceContainer..."
$blobs = (az storage blob list `
    --container-name $SourceContainer `
    --account-name $StorageAccount `
    --auth-mode login `
    --output json 2>&1) | ConvertFrom-Json

# Filter to actual files only (size > 0)
$realBlobs = $blobs | Where-Object { $_.properties.contentLength -gt 0 }
Write-Host "[INFO] Total blobs: $($blobs.Count)  |  Actual files to copy: $($realBlobs.Count)"

if ($realBlobs.Count -eq 0) {
    Write-Host "[WARN] No files found to migrate."
    exit 0
}

$migrated = 0
$skipped  = 0
$errors   = 0
$log      = [System.Collections.Generic.List[string]]::new()

# Get account key once for same-account server-side copy (--auth-mode login not
# supported as copy source; account key is required)
$accountKey = $null
if (-not $DryRun) {
    Write-Host "[INFO] Getting storage account key for copy auth..."
    $accountKey = az storage account keys list `
        --account-name $StorageAccount `
        --resource-group EsDAICoE-Sandbox `
        --query "[0].value" -o tsv 2>&1
    if ($LASTEXITCODE -ne 0 -or $accountKey -notmatch "^[A-Za-z0-9+/=]{80,}") {
        Write-Host "[FAIL] Could not retrieve account key: $accountKey"
        exit 1
    }
    Write-Host "[PASS] Account key retrieved"
}

foreach ($blob in $realBlobs) {
    $srcName  = $blob.name
    $destName = "$DestinationPrefix/$srcName"

    if ($DryRun) {
        $msg = "[DRY-RUN] $srcName => $DestinationContainer/$destName  ($([math]::Round($blob.properties.contentLength/1024))KB)"
        Write-Host $msg
        $log.Add($msg)
        $migrated++
        continue
    }

    # Check if destination already exists
    $exists = az storage blob exists `
        --container-name $DestinationContainer `
        --account-name $StorageAccount `
        --name $destName `
        --account-key $accountKey `
        --query "exists" -o tsv 2>&1

    if ($exists -eq "true") {
        $msg = "[SKIP] Already exists: $destName"
        Write-Host $msg
        $log.Add($msg)
        $skipped++
        continue
    }

    # Server-side copy: source and dest in same account, use account key
    $copyResult = az storage blob copy start `
        --account-name $StorageAccount `
        --account-key $accountKey `
        --destination-container $DestinationContainer `
        --destination-blob $destName `
        --source-container $SourceContainer `
        --source-blob $srcName 2>&1

    if ($LASTEXITCODE -eq 0) {
        $msg = "[PASS] Copied: $srcName ($([math]::Round($blob.properties.contentLength/1024))KB)"
        Write-Host $msg
        $log.Add($msg)
        $migrated++
    } else {
        $msg = "[FAIL] Error copying $srcName : $copyResult"
        Write-Host $msg
        $log.Add($msg)
        $errors++
    }
}

# Summary
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host ""
Write-Host "================================================================"
Write-Host "  Migration Summary [$mode]"
Write-Host "================================================================"
Write-Host "  Copied:  $migrated"
Write-Host "  Skipped: $skipped (already existed)"
Write-Host "  Errors:  $errors"
Write-Host "================================================================"

# Save log
$logPath = "c:\eva-foundry-local\14-az-finops\scripts\migration-log-$ts.txt"
$log | Out-File -FilePath $logPath -Encoding utf8
Write-Host "[INFO] Log saved: $logPath"

if ($errors -gt 0) { exit 1 } else { exit 0 }
