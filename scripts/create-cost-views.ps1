# EVA-FEATURE: F14-08
# EVA-STORY: F14-08-001
<#
.SYNOPSIS
    Create Cost Management saved views via REST API.

.DESCRIPTION
    Uses `az rest` to PUT three named Cost Analysis views in the target
    subscription:
      1. FinOps-By-SscBillingCode    – monthly bar chart grouped by ssc_cbrid tag
      2. FinOps-By-FinancialAuthority – monthly bar chart grouped by fin_financialauthority tag
      3. FinOps-By-Environment        – monthly bar chart grouped by environment tag,
                                        pre-filtered to project=GHCP-Sandbox

    Views are created at subscription scope and are visible to anyone with
    Cost Management Reader rights.

.PARAMETER SubscriptionId
    Target subscription. Defaults to EsDAICoESub.

.PARAMETER WhatIf
    Print the JSON body without calling the API.

.EXAMPLE
    .\create-cost-views.ps1
    .\create-cost-views.ps1 -WhatIf
#>

[CmdletBinding()]
param(
    [string]$SubscriptionId = 'd2d4e571-e0f2-4f6c-901a-f88f7669bcba',
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$API_VERSION = '2023-11-01'
$SCOPE       = "/subscriptions/$SubscriptionId"
$BASE_URL    = "https://management.azure.com$SCOPE/providers/Microsoft.CostManagement/views"

function Write-Log($msg, $level = 'INFO') {
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $colour = switch ($level) { 'ERROR' { 'Red' } 'WARN' { 'Yellow' } 'OK' { 'Green' } default { 'Cyan' } }
    Write-Host "[$ts] [$level] $msg" -ForegroundColor $colour
}

# ── helper: base dataset with common aggregation ─────────────────────────────
function New-ViewDataset([string]$groupTagKey, [hashtable]$filter = $null) {
    $aggregation = @{
        totalCost = @{ name = 'PreTaxCost'; function = 'Sum' }
    }
    $grouping = @(
        @{ type = 'TagKey'; name = $groupTagKey },
        @{ type = 'Dimension'; name = 'ResourceGroupName' }
    )
    $ds = @{
        granularity  = 'Monthly'
        aggregation  = $aggregation
        grouping     = $grouping
        sorting      = @(@{ name = 'PreTaxCost'; direction = 'Descending' })
    }
    if ($filter -and $filter.Count -gt 0) { $ds['filter'] = $filter }
    return $ds
}

# ── view definitions ──────────────────────────────────────────────────────────
# The Cost Management View API requires exactly 3 pivots for non-table charts.
# Pivots[0] = primary legend (tag/dimension we group on), [1]+[2] = secondary axes.
$views = @(
    @{
        name        = 'FinOps-By-SscBillingCode'
        displayName = 'FinOps – Cost by SSC Billing Code (ssc_cbrid)'
        chart       = 'GroupedColumn'
        tagKey      = 'ssc_cbrid'
        filter      = @{}
        pivots      = @(
            @{ type = 'TagKey';    name = 'ssc_cbrid' },
            @{ type = 'Dimension'; name = 'ServiceName' },
            @{ type = 'Dimension'; name = 'ResourceGroupName' }
        )
    },
    @{
        name        = 'FinOps-By-FinancialAuthority'
        displayName = 'FinOps – Cost by Financial Authority (fin_financialauthority)'
        chart       = 'GroupedColumn'
        tagKey      = 'fin_financialauthority'
        filter      = @{}
        pivots      = @(
            @{ type = 'TagKey';    name = 'fin_financialauthority' },
            @{ type = 'Dimension'; name = 'ServiceName' },
            @{ type = 'Dimension'; name = 'ResourceGroupName' }
        )
    },
    @{
        name        = 'FinOps-By-Environment'
        displayName = 'FinOps – Cost by Environment (project=GHCP-Sandbox)'
        chart       = 'GroupedColumn'
        tagKey      = 'environment'
        # Direct tags filter (no 'and' wrapper) for a single condition
        filter      = @{
            tags = @{
                name     = 'project'
                operator = 'In'
                values   = @('GHCP-Sandbox')
            }
        }
        pivots      = @(
            @{ type = 'TagKey';    name = 'environment' },
            @{ type = 'Dimension'; name = 'ServiceName' },
            @{ type = 'Dimension'; name = 'ResourceGroupName' }
        )
    }
)

# ── main loop ─────────────────────────────────────────────────────────────────
$results = @()

foreach ($v in $views) {
    $url = "$BASE_URL/$($v.name)?api-version=$API_VERSION"

    $body = @{
        eTag       = '*'
        properties = @{
            displayName = $v.displayName
            scope       = $SCOPE
            query       = @{
                type      = 'ActualCost'
                dataSet   = (New-ViewDataset -groupTagKey $v.tagKey -filter $v.filter)
                timeframe = 'MonthToDate'
            }
            chart       = $v.chart
            accumulated = 'false'
            metric      = 'ActualCost'
            kpis        = @()
            pivots      = $v.pivots
        }
    }

    $bodyJson = $body | ConvertTo-Json -Depth 20 -Compress
    Write-Log "PUT $($v.name)"

    if ($WhatIf) {
        Write-Host ($body | ConvertTo-Json -Depth 20) -ForegroundColor DarkGray
        $results += [PSCustomObject]@{ View = $v.name; Status = 'WhatIf' }
        continue
    }

    # Write body to temp file to avoid shell quoting issues on Windows
    $tmp = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmp, $bodyJson, [System.Text.Encoding]::UTF8)

    try {
        $resp = az rest `
            --method  PUT `
            --url     $url `
            --body    "@$tmp" `
            --headers "Content-Type=application/json" `
            | ConvertFrom-Json

        if ($null -ne $resp.id) {
            Write-Log "  Created: $($resp.id)" OK
            $results += [PSCustomObject]@{ View = $v.name; Status = 'OK'; Id = $resp.id }
        } else {
            Write-Log "  Unexpected response: $($resp | ConvertTo-Json -Compress)" WARN
            $results += [PSCustomObject]@{ View = $v.name; Status = 'Unknown'; Id = '' }
        }
    } catch {
        Write-Log "  FAILED: $_" ERROR
        $results += [PSCustomObject]@{ View = $v.name; Status = 'Error'; Id = $_.ToString() }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
Write-Log '─── Summary ──────────────────────────────────────────────────────' INFO
$results | Format-Table -AutoSize

# ── portal deep-links ─────────────────────────────────────────────────────────
$tenant   = 'hrsdc-rhdcc.gc.ca'
$basePortal = "https://portal.azure.com/#@$tenant/resource$SCOPE/costmanagement/costanalysis"
Write-Host ''
Write-Log 'Portal URLs to open saved views:' INFO
foreach ($r in ($results | Where-Object { $_.Status -eq 'OK' })) {
    Write-Host "  $($r.View): $basePortal" -ForegroundColor Green
}
