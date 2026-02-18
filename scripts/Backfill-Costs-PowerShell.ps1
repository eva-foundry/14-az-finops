<#
.SYNOPSIS
    Backfill historical Azure cost data using PowerShell cmdlets (better than REST API for detailed data)
    
.DESCRIPTION
    Alternative to REST API approach - uses Get-AzConsumptionUsageDetail which is optimized
    for retrieving detailed resource-level cost data without aggressive rate limiting.
    
.NOTES
    Created: 2026-02-16
    Why PowerShell cmdlets: REST API Query endpoint heavily throttled when grouping by dimensions.
    PowerShell cmdlets use different backend APIs designed for bulk data retrieval.
#>

param(
    [int]$MonthsToBackfill = 1
)

$ErrorActionPreference = "Stop"

# Subscription configuration
$Subscriptions = @(
    @{ Name = "EsDAICoESub"; Id = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba" },
    @{ Name = "EsPAICoESub"; Id = "802d84ab-3189-4221-8453-fcc30c8dc8ea" }
)

# Output directory
$outputDir = Join-Path $PSScriptRoot "..\output\historical"
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }

# Simple logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

Write-Log "Starting PowerShell cmdlet-based backfill for $MonthsToBackfill month(s)"

# Generate month list
$startMonth = (Get-Date).AddMonths(-$MonthsToBackfill)
$monthList = @()
for ($i=0; $i -lt $MonthsToBackfill; $i++){
    $m = $startMonth.AddMonths($i)
    $monthList += @{ Year = $m.Year; Month = $m.Month; MonthKey = $m.ToString('yyyy-MM') }
}

foreach ($sub in $Subscriptions) {
    $subOutput = Join-Path $outputDir $sub.Name
    if (-not (Test-Path $subOutput)) { New-Item -ItemType Directory -Path $subOutput -Force | Out-Null }

    Write-Log "Processing subscription: $($sub.Name)"
    
    # Set subscription context
    try {
        Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop | Out-Null
    } catch {
        Write-Log "Failed to set subscription context for $($sub.Name): $_" "ERROR"
        continue
    }

    foreach ($m in $monthList) {
        $monthKey = $m.MonthKey
        $monthStart = Get-Date -Year $m.Year -Month $m.Month -Day 1
        $monthEnd = ($monthStart.AddMonths(1)).AddDays(-1)

        Write-Log "Backfilling $($sub.Name) $monthKey (from $($monthStart.ToString('yyyy-MM-dd')) to $($monthEnd.ToString('yyyy-MM-dd')))"

        $outFile = Join-Path $subOutput "costs_${monthKey}_PowerShell.csv"

        try {
            # Get usage details using PowerShell cmdlet
            # This cmdlet is optimized for bulk data retrieval and has better rate limits
            Write-Log "Calling Get-AzConsumptionUsageDetail..."
            
            $usageDetails = Get-AzConsumptionUsageDetail `
                -StartDate $monthStart `
                -EndDate $monthEnd `
                -IncludeMeterDetails `
                -IncludeAdditionalProperties `
                -ErrorAction Stop
            
            if ($usageDetails.Count -eq 0) {
                Write-Log "No usage details returned for $monthKey" "WARN"
                continue
            }

            Write-Log "Retrieved $($usageDetails.Count) usage records"

            # Convert to CSV-friendly format
            $csvData = $usageDetails | Select-Object `
                @{N='Date';E={$_.Date}}, `
                @{N='ResourceId';E={$_.InstanceId}}, `
                @{N='ResourceName';E={$_.InstanceName}}, `
                @{N='ResourceType';E={$_.ConsumedService}}, `
                @{N='ResourceLocation';E={$_.InstanceLocation}}, `
                @{N='ResourceGroup';E={
                    if ($_.InstanceId -match '/resourcegroups/([^/]+)/') { $matches[1] } else { '' }
                }}, `
                @{N='MeterCategory';E={$_.MeterDetails.MeterCategory}}, `
                @{N='MeterSubCategory';E={$_.MeterDetails.MeterSubCategory}}, `
                @{N='MeterName';E={$_.MeterDetails.MeterName}}, `
                @{N='Quantity';E={$_.Quantity}}, `
                @{N='Unit';E={$_.MeterDetails.Unit}}, `
                @{N='PreTaxCost';E={$_.PretaxCost}}, `
                @{N='Currency';E={$_.Currency}}, `
                @{N='Tags';E={ 
                    if ($_.Tags) { ($_.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ';' } else { '' }
                }}

            # Export to CSV
            $csvData | Export-Csv -Path $outFile -NoTypeInformation -Force
            Write-Log "Saved $($csvData.Count) rows to $outFile"

        } catch {
            Write-Log "Error retrieving usage details for $monthKey`: $_" "ERROR"
            # Don't throw - continue with next month/subscription
        }
    }
}

Write-Log "Backfill complete!"
