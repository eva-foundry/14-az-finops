<#
.SYNOPSIS
    Backfill Azure cost data using REST API with proper pagination handling.

.DESCRIPTION
    Uses `az rest` to query the Cost Management API for a subscription and
    time period, follows `nextLink` for pagination, and writes CSV output
    to `output\historical\{subscription}` per-month.

.PARAMETER MonthsToBackfill
    Number of months to backfill. Default: 12

.PARAMETER Subscriptions
    Array of @{Name='EsDAICoESub'; Id='d2d4e571-...'} objects. Default: EsDAICoESub + EsPAICoESub

.EXAMPLE
    .\Backfill-Costs-REST.ps1 -MonthsToBackfill 1
#>

[CmdletBinding()]
param(
    [int]$MonthsToBackfill = 12,
    [array]$Subscriptions = @(
        @{ Name = 'EsDAICoESub'; Id = 'd2d4e571-e0f2-4f6c-901a-f88f7669bcba' },
        @{ Name = 'EsPAICoESub'; Id = '802d84ab-3189-4221-8453-fcc30c8dc8ea' }
    ),
    [int]$InterRequestDelay = 1
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = Join-Path $scriptDir "..\output\historical"
$outputDir = (Resolve-Path $outputDir).ProviderPath

function Write-Log($msg, $level='INFO'){
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Host "[$ts] [$level] $msg"
}

function Invoke-CostRestQuery {
    param(
        [string]$Scope,
        [string]$BodyJson,
        [int]$MaxRetries = 5
    )
    $uri = "https://management.azure.com${Scope}/providers/Microsoft.CostManagement/query?api-version=2021-10-01"

    $results = @()
    $next = $uri
    $body = $BodyJson

    while ($next) {
        Write-Log "Calling REST: $next"
        
        $retryCount = 0
        $success = $false
        $resp = $null
        
        while (-not $success -and $retryCount -lt $MaxRetries) {
            try {
                if ($body) {
                    # Write body to temp file for az rest
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    $body | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline
                    
                    # Capture stderr to detect 429 errors
                    $output = az rest --method post --uri $next --body "@$tempFile" --headers "Content-Type=application/json" 2>&1
                    Remove-Item $tempFile -ErrorAction SilentlyContinue
                } else {
                    # No body for nextLink calls
                    $output = az rest --method post --uri $next --headers "Content-Type=application/json" 2>&1
                }
                
                # Check for rate limiting error
                if ($output -match "429|Too Many Requests") {
                    $retryCount++
                    $waitSeconds = [Math]::Pow(2, $retryCount) * 5  # Exponential backoff: 10, 20, 40, 80, 160 seconds
                    Write-Log "Rate limited (429). Retry $retryCount/$MaxRetries after ${waitSeconds}s" 'WARN'
                    Start-Sleep -Seconds $waitSeconds
                    continue
                }
                
                # Parse JSON response
                $resp = $output | ConvertFrom-Json
                if ($null -eq $resp) { throw "Empty response from az rest" }
                
                $success = $true
                
            } catch {
                $retryCount++
                if ($retryCount -ge $MaxRetries) {
                    throw "Max retries exceeded: $_"
                }
                $waitSeconds = [Math]::Pow(2, $retryCount) * 5
                Write-Log "Error (retry $retryCount/$MaxRetries after ${waitSeconds}s): $_" 'WARN'
                Start-Sleep -Seconds $waitSeconds
            }
        }
        
        if (-not $success) {
            throw "Failed to retrieve data after $MaxRetries retries"
        }

        # Extract rows if present
        if ($resp.properties -and $resp.properties.rows) {
            $rows = $resp.properties.rows
            $columns = $resp.properties.columns | ForEach-Object { $_.name }
            foreach ($r in $rows) {
                $obj = @{}
                for ($i=0; $i -lt $columns.Count; $i++){
                    $obj[$columns[$i]] = $r[$i]
                }
                $results += (New-Object psobject -Property $obj)
            }
        }

        if ($resp.nextLink) {
            $next = $resp.nextLink
            # After first call, body must be null for nextLink calls
            $body = $null
            Start-Sleep -Seconds $InterRequestDelay
        } else {
            $next = $null
        }
    }

    return $results
}

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

    foreach ($m in $monthList) {
        $monthKey = $m.MonthKey
        $monthStart = Get-Date -Year $m.Year -Month $m.Month -Day 1 -Hour 0 -Minute 0 -Second 0
        $monthEnd = ($monthStart.AddMonths(1)).AddSeconds(-1)

        Write-Log "Backfilling $($sub.Name) $monthKey"

        $scope = "/subscriptions/$($sub.Id)"
        $fromDate = $monthStart.ToString('yyyy-MM-ddT00:00:00Z')
        $toDate = $monthEnd.ToString('yyyy-MM-ddTHH:mm:ss') + 'Z'
        
        $body = @{
            type = "ActualCost"
            timeframe = "Custom"
            timePeriod = @{ 
                from = $fromDate
                to = $toDate
            }
            dataset = @{
                granularity = "Daily"
                aggregation = @{ totalCost = @{ name = "PreTaxCost"; function = "Sum" } }
                grouping = @(
                    @{ type = "Dimension"; name = "ResourceId" },
                    @{ type = "Dimension"; name = "ResourceType" },
                    @{ type = "Dimension"; name = "ResourceGroupName" }
                )
            }
        } | ConvertTo-Json -Depth 10

        try {
            $rows = Invoke-CostRestQuery -Scope $scope -BodyJson $body
            if ($rows.Count -eq 0) { Write-Log "No rows returned for $monthKey" 'WARN'; continue }

            $outFile = Join-Path $subOutput "costs_${monthKey}_REST.csv"
            $rows | Export-Csv -Path $outFile -NoTypeInformation -Force
            Write-Log "Wrote $($rows.Count) rows to $outFile"
        } catch {
            Write-Log "Error backfilling ${monthKey}: $($_.Exception.Message)" 'ERROR'
        }

        Start-Sleep -Seconds 2
    }
}

Write-Log "Backfill complete" 'SUCCESS'
