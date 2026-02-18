#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create 12 monthly one-time exports for EsPAICoESub (Production) - Feb 2025 to Jan 2026

.DESCRIPTION
    Automates creation of Cost Management exports for historical data analysis.
    Uses Azure REST API to create export definitions with 2024-08-01 schema.

.PARAMETER StorageAccountName
    Target storage account (default: marcosandboxfinopshub)

.PARAMETER ContainerName
    Storage container (default: costs)

.PARAMETER DryRun
    Preview export definitions without creating them

.EXAMPLE
    .\Create-Monthly-Exports-EsPAICoESub.ps1
    .\Create-Monthly-Exports-EsPAICoESub.ps1 -DryRun

.NOTES
    Author: Marco Presta
    Date: 2026-02-17
    Subscription: EsPAICoESub (802d84ab-3189-4221-8453-fcc30c8dc8ea)
    Schema: 2024-08-01 (matches daily export)
#>

[CmdletBinding()]
param(
    [string]$StorageAccountName = "marcosandboxfinopshub",
    [string]$ContainerName = "costs",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$subscriptionId = "802d84ab-3189-4221-8453-fcc30c8dc8ea"
$subscriptionName = "EsPAICoESub"
$apiVersion = "2023-08-01"
$datasetVersion = "2024-08-01"

# Storage account resource ID
$storageResourceId = "/subscriptions/$subscriptionId/resourceGroups/rg-sandbox-marco/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"

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

Write-Host "[INFO] Creating monthly exports for $subscriptionName" -ForegroundColor Cyan
Write-Host "[INFO] Subscription ID: $subscriptionId"
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
Write-Host ""

# Create exports
$successCount = 0
$failCount = 0
$results = @()

foreach ($range in $monthlyRanges) {
    $exportName = "$subscriptionName-$($range.Name)"
    
    Write-Host "[INFO] Creating export: $exportName ($($range.Month))" -ForegroundColor Yellow
    
    # Build export definition
    $exportDefinition = @{
        properties = @{
            schedule = @{
                status = "Inactive"
                recurrence = "OneTime"
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
                    rootFolderPath = "$subscriptionName/$subscriptionName-$($range.Name)"
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
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CostManagement/exports/$exportName`?api-version=$apiVersion"
    
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
            $runUri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CostManagement/exports/$exportName/run?api-version=$apiVersion"
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
                BlobPath = "$subscriptionName/$subscriptionName-$($range.Name)"
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
    Write-Host "  3. Run download script: .\Download-Monthly-Exports-EsPAICoESub.ps1"
    Write-Host ""
    Write-Host "[INFO] Blob storage location:" -ForegroundColor Yellow
    Write-Host "  Container: $ContainerName"
    Write-Host "  Path pattern: $subscriptionName/$subscriptionName-YYYY-MM/YYYYMMDD-YYYYMMDD/{guid}/part_0_0001.csv.gz"
}

Write-Host ""
Write-Host "[INFO] Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
