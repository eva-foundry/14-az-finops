#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create 12 monthly one-time exports for specified subscription (Feb 2025 - Jan 2026)

.DESCRIPTION
    Automates creation of Cost Management exports for historical data analysis.
    Uses Azure REST API to create export definitions with 2024-08-01 schema.
    Works with any Azure subscription.

.PARAMETER SubscriptionId
    Azure subscription ID (required)

.PARAMETER SubscriptionName
    Friendly name for subscription (required, e.g., "EsDAICoESub", "EsPAICoESub")

.PARAMETER StorageAccountName
    Target storage account (default: marcosandboxfinopshub)

.PARAMETER ContainerName
    Storage container (default: costs)

.PARAMETER StorageResourceGroup
    Resource group containing storage account (default: rg-sandbox-marco)

.PARAMETER DryRun
    Preview export definitions without creating them

.EXAMPLE
    .\Create-Monthly-Exports.ps1 -SubscriptionId "d2d4e571-..." -SubscriptionName "EsDAICoESub"
    .\Create-Monthly-Exports.ps1 -SubscriptionId "802d84ab-..." -SubscriptionName "EsPAICoESub" -DryRun

.NOTES
    Author: Marco Presta
    Date: 2026-02-17
    Schema: 2024-08-01 (matches daily export)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionName,
    
    [string]$StorageAccountName = "marcosandboxfinopshub",
    [string]$ContainerName = "costs",
    [string]$StorageResourceGroup = "rg-sandbox-marco",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$apiVersion = "2023-08-01"
$datasetVersion = "2024-08-01"

# Storage account resource ID
$storageResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$StorageResourceGroup/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"

# Define 12 monthly date ranges
$monthlyRanges = @(
    @{ Name = "2025-02"; StartDate = "2025-02-01"; EndDate = "2025-02-28"; Month = "February 2025" }
    @{ Name = "2025-03"; StartDate = "2025-03-01"; EndDate = "2025-03-31"; Month = "March 2025" }
    @{ Name = "2025-04"; StartDate = "2025-04-01"; EndDate = "2025-04-30"; Month = "April 2025" }
    @{ Name = "2025-05"; StartDate = "2025-05-01"; EndDate = "2025-05-31"; Month = "May 2025" }
    @{ Name = "2025-06"; StartDate = "2025-06-01"; EndDate = "2025-06-30"; Month = "June 2025" }
    @{ Name = "2025-07"; StartDate = "2025-07-01"; EndDate = "2025-07-31"; Month = "July 2025" }
    @{ Name = "2025-08"; StartDate = "2025-08-01"; EndDate = "2025-08-31"; Month = "August 2025" }
    @{ Name = "2025-09"; StartDate = "2025-09-01"; EndDate = "2025-09-30"; Month = "September 2025" }
    @{ Name = "2025-10"; StartDate = "2025-10-01"; EndDate = "2025-10-31"; Month = "October 2025" }
    @{ Name = "2025-11"; StartDate = "2025-11-01"; EndDate = "2025-11-30"; Month = "November 2025" }
    @{ Name = "2025-12"; StartDate = "2025-12-01"; EndDate = "2025-12-31"; Month = "December 2025" }
    @{ Name = "2026-01"; StartDate = "2026-01-01"; EndDate = "2026-01-31"; Month = "January 2026" }
)

Write-Host "[INFO] Creating monthly exports for $SubscriptionName" -ForegroundColor Cyan
Write-Host "[INFO] Subscription ID: $SubscriptionId"
Write-Host "[INFO] Storage: $StorageAccountName/$ContainerName"
Write-Host "[INFO] Dataset version: $datasetVersion"
Write-Host "[INFO] Total exports to create: $($monthlyRanges.Count)"
Write-Host ""

# Check Azure CLI authentication
$currentAccount = az account show 2>$null | ConvertFrom-Json
if (-not $currentAccount) {
    Write-Host "[FAIL] Not logged into Azure CLI. Run: az login" -ForegroundColor Red
    exit 1
}

Write-Host "[PASS] Authenticated as: $($currentAccount.user.name)" -ForegroundColor Green

# Verify subscription access
Write-Host "[INFO] Verifying subscription access..."
az account set --subscription $SubscriptionId 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Cannot access subscription: $SubscriptionId" -ForegroundColor Red
    Write-Host "[INFO] Check permissions or use: az account list" -ForegroundColor Yellow
    exit 1
}
Write-Host "[PASS] Subscription access verified" -ForegroundColor Green
Write-Host ""

# Create exports
$successCount = 0
$failCount = 0
$results = @()

foreach ($range in $monthlyRanges) {
    $exportName = "$SubscriptionName-$($range.Name)"
    
    Write-Host "[INFO] Creating export: $exportName ($($range.Month))" -ForegroundColor Yellow
    
    # Build export definition
    $exportDefinition = @{
        properties = @{
            schedule = @{
                status = "Inactive"
            }
            definition = @{
                type = "ActualCost"
                timeframe = "Custom"
                timePeriod = @{
                    from = "$($range.StartDate)T00:00:00Z"
                    to = "$($range.EndDate)T23:59:59Z"
                }
                dataSet = @{
                    granularity = "Daily"
                    configuration = @{
                        dataVersion = $datasetVersion
                    }
                }
            }
            deliveryInfo = @{
                destination = @{
                    resourceId = $storageResourceId
                    container = $ContainerName
                    rootFolderPath = "$SubscriptionName/$SubscriptionName-$($range.Name)"
                }
            }
            format = "Csv"
            partitionData = $true
        }
    } | ConvertTo-Json -Depth 10
    
    if ($DryRun) {
        Write-Host "[DRY RUN] Export definition:" -ForegroundColor Magenta
        Write-Host $exportDefinition
        Write-Host ""
        $successCount++
        continue
    }
    
    # Create export via REST API
    $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CostManagement/exports/$exportName`?api-version=$apiVersion"
    
    try {
        # Save to temp file (workaround for HTTP 415)
        $tempFile = [System.IO.Path]::GetTempFileName()
        $exportDefinition | Out-File -FilePath $tempFile -Encoding utf8 -Force
        
        $response = az rest --method PUT --uri $uri --body "@$tempFile" 2>&1
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[PASS] Export created successfully" -ForegroundColor Green
            $successCount++
            
            # Trigger immediate run
            Write-Host "[INFO] Triggering export execution..."
            $runUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.CostManagement/exports/$exportName/run?api-version=$apiVersion"
            az rest --method POST --uri $runUri --output none 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[PASS] Export execution triggered" -ForegroundColor Green
            } else {
                Write-Host "[WARN] Manual trigger failed - export will run on schedule" -ForegroundColor Yellow
            }
            
            $results += [PSCustomObject]@{
                ExportName = $exportName
                Month = $range.Month
                DateRange = "$($range.StartDate) to $($range.EndDate)"
                Status = "Created"
                BlobPath = "$SubscriptionName/$SubscriptionName-$($range.Name)"
            }
        } else {
            Write-Host "[FAIL] Failed to create export: $response" -ForegroundColor Red
            $failCount++
            
            $results += [PSCustomObject]@{
                ExportName = $exportName
                Month = $range.Month
                DateRange = "$($range.StartDate) to $($range.EndDate)"
                Status = "Failed"
                BlobPath = "N/A"
            }
        }
    } catch {
        Write-Host "[FAIL] Exception: $_" -ForegroundColor Red
        $failCount++
    }
    
    Write-Host ""
}

# Summary
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "EXPORT CREATION SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "[INFO] Total exports: $($monthlyRanges.Count)"
Write-Host "[PASS] Successfully created: $successCount" -ForegroundColor Green
Write-Host "[FAIL] Failed: $failCount" -ForegroundColor Red
Write-Host ""

if ($results.Count -gt 0) {
    Write-Host "Detailed Results:" -ForegroundColor Cyan
    $results | Format-Table -AutoSize
}

if (-not $DryRun -and $successCount -gt 0) {
    Write-Host ""
    Write-Host "[INFO] Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Wait 5-10 minutes for exports to complete"
    Write-Host "  2. Check export status in Portal: Cost Management > Exports > Export history"
    Write-Host "  3. Run download script:"
    Write-Host "     .\Download-Monthly-Exports.ps1 -SubscriptionId '$SubscriptionId' -SubscriptionName '$SubscriptionName'"
    Write-Host ""
    Write-Host "[INFO] Blob storage location:" -ForegroundColor Yellow
    Write-Host "  Container: $ContainerName"
    Write-Host "  Path pattern: $SubscriptionName/$SubscriptionName-YYYY-MM/YYYYMMDD-YYYYMMDD/{guid}/part_0_0001.csv.gz"
}

Write-Host ""
Write-Host "[INFO] Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
