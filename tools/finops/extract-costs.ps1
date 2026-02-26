<#
.SYNOPSIS
    Extracts 3 months of daily cost data from EsDAICoESub Cost Management API.
    Writes raw JSON to tools/finops/raw/ for ingestion by build-db.py.

    Queries (sequential, 12s apart to stay under 6 req/min quota):
        1. Daily cost by MeterCategory          → raw/daily_by_service.json
        2. Daily cost by ResourceGroup          → raw/daily_by_rg.json
        3. Daily cost by ServiceName            → raw/daily_by_meter.json
        4. Monthly cost by MeterCategory+RG     → raw/monthly_by_service_rg.json
#>

$SUB  = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$URL  = "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
$FROM = "2025-11-27T00:00:00Z"
$TO   = "2026-02-26T23:59:59Z"

$RAW  = "$PSScriptRoot\raw"
New-Item -ItemType Directory -Path $RAW -Force | Out-Null

function Invoke-CostAPI([hashtable]$body, [string]$outFile) {
    $tmp = [System.IO.Path]::GetTempFileName() + ".json"
    ($body | ConvertTo-Json -Depth 10) | Out-File $tmp -Encoding utf8NoBOM
    Write-Host "  Querying → $outFile ..." -NoNewline
    $response = az rest --method POST --url $URL `
        --body "@$tmp" `
        --headers "Content-Type=application/json" `
        --only-show-errors 2>&1
    Remove-Item $tmp -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0 -or -not $response) {
        Write-Host " FAILED ($LASTEXITCODE)" -ForegroundColor Red
        return $false
    }
    $response | Out-File "$RAW\$outFile" -Encoding utf8NoBOM
    $rows = ($response | ConvertFrom-Json).properties.rows.Count
    Write-Host " OK ($rows rows)" -ForegroundColor Green
    Start-Sleep -Seconds 12   # ~5 req/min safety margin
    return $true
}

Write-Host "`n=== Cost Extraction — EsDAICoESub ===" -ForegroundColor Cyan
Write-Host "Period : $FROM → $TO"
Write-Host "Output : $RAW`n"

# ── 1. Daily by MeterCategory ──────────────────────────────────────────────
Invoke-CostAPI @{
    type = "ActualCost"; timeframe = "Custom"
    timePeriod = @{ from = $FROM; to = $TO }
    dataset = @{
        granularity = "Daily"
        aggregation = @{ totalCost = @{ name = "Cost"; function = "Sum" } }
        grouping    = @( @{ type = "Dimension"; name = "MeterCategory" } )
    }
} "daily_by_service.json"

# ── 2. Daily by ResourceGroup ──────────────────────────────────────────────
Invoke-CostAPI @{
    type = "ActualCost"; timeframe = "Custom"
    timePeriod = @{ from = $FROM; to = $TO }
    dataset = @{
        granularity = "Daily"
        aggregation = @{ totalCost = @{ name = "Cost"; function = "Sum" } }
        grouping    = @( @{ type = "Dimension"; name = "ResourceGroupName" } )
    }
} "daily_by_rg.json"

# ── 3. Daily by ServiceName (meter-level) ─────────────────────────────────
Invoke-CostAPI @{
    type = "ActualCost"; timeframe = "Custom"
    timePeriod = @{ from = $FROM; to = $TO }
    dataset = @{
        granularity = "Daily"
        aggregation = @{ totalCost = @{ name = "Cost"; function = "Sum" } }
        grouping    = @( @{ type = "Dimension"; name = "ServiceName" } )
    }
} "daily_by_meter.json"

# ── 4. Monthly rollup by MeterCategory + ResourceGroup ────────────────────
Invoke-CostAPI @{
    type = "ActualCost"; timeframe = "Custom"
    timePeriod = @{ from = $FROM; to = $TO }
    dataset = @{
        granularity = "Monthly"
        aggregation = @{ totalCost = @{ name = "Cost"; function = "Sum" } }
        grouping    = @(
            @{ type = "Dimension"; name = "MeterCategory" }
            @{ type = "Dimension"; name = "ResourceGroupName" }
        )
    }
} "monthly_by_service_rg.json"

Write-Host "`nDone. Run: python tools/finops/build-db.py" -ForegroundColor Yellow
