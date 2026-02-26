# EVA-FEATURE: F14-08
# EVA-STORY: F14-08-003
<#
.SYNOPSIS
    Create an Azure Portal Dashboard for FinOps cost monitoring via REST API.

.DESCRIPTION
    Uses `az rest` to PUT a portal dashboard named "FinOps-EsDAICoESub" in the
    EsDAICoE-Sandbox resource group.  The dashboard contains six tiles:

      Row 0  [full width]   Markdown header with scope + documentation link
      Row 1  [left]         Cost by SSC Billing Code (bar chart, MTD)
      Row 1  [right]        Cost by Financial Authority (bar chart, MTD)
      Row 2  [left]         Cost by Environment (bar chart, MTD, GHCP-Sandbox filter)
      Row 2  [right]        Cost by Owner/Manager (bar chart, MTD)
      Row 3  [full width]   Budget status tile – FinOps-Budget-EsDAICoESub-Total

    Dashboard is shared at resource-group scope; anyone with Contributor or
    Dashboard Contributor on EsDAICoE-Sandbox can view and pin it.

.PARAMETER SubscriptionId
    Defaults to EsDAICoESub.

.PARAMETER ResourceGroup
    Defaults to EsDAICoE-Sandbox.

.PARAMETER DashboardName
    Defaults to FinOps-EsDAICoESub.

.PARAMETER WhatIf
    Print the JSON body without calling the API.

.EXAMPLE
    .\create-dashboard.ps1
    .\create-dashboard.ps1 -WhatIf | Out-String | clip
#>

[CmdletBinding()]
param(
    [string]$SubscriptionId = 'd2d4e571-e0f2-4f6c-901a-f88f7669bcba',
    [string]$ResourceGroup  = 'EsDAICoE-Sandbox',
    [string]$DashboardName  = 'FinOps-EsDAICoESub',
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$API_VERSION = '2020-09-01-preview'
$SCOPE       = "/subscriptions/$SubscriptionId"
$URL         = "https://management.azure.com$SCOPE/resourceGroups/$ResourceGroup" +
               "/providers/Microsoft.Portal/dashboards/$DashboardName" +
               "?api-version=$API_VERSION"

function Write-Log($msg, $level = 'INFO') {
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $colour = switch ($level) { 'ERROR' { 'Red' } 'WARN' { 'Yellow' } 'OK' { 'Green' } default { 'Cyan' } }
    Write-Host "[$ts] [$level] $msg" -ForegroundColor $colour
}

# ── tile helpers ──────────────────────────────────────────────────────────────

function New-Position([int]$x, [int]$y, [int]$colSpan, [int]$rowSpan) {
    return @{ x = $x; y = $y; colSpan = $colSpan; rowSpan = $rowSpan }
}

function New-CostTile {
    param(
        [string]$id,
        [int]$x, [int]$y,
        [string]$title,
        [string]$groupTagKey,
        [hashtable]$filter = @{}
    )

    $dataSet = @{
        granularity  = 'Monthly'
        aggregation  = @{ totalCost = @{ name = 'PreTaxCost'; function = 'Sum' } }
        grouping     = @( @{ type = 'TagKey'; name = $groupTagKey } )
        sorting      = @( @{ name = 'PreTaxCost'; direction = 'Descending' } )
    }
    if ($filter.Count -gt 0) { $dataSet['filter'] = $filter }

    return @{
        position = New-Position $x $y 6 4
        metadata = @{
            type    = 'Extension/Microsoft_Azure_CostManagement/PartType/CostAnalysisPart'
            inputs  = @(
                @{ name = 'id'; value = $SCOPE }
            )
            settings = @{
                content = @{
                    scope       = $SCOPE
                    view        = @{
                        displayName = $title
                        chart       = 'GroupedColumn'
                        accumulated = 'false'
                        metric      = 'ActualCost'
                        query       = @{
                            type      = 'ActualCost'
                            dataSet   = $dataSet
                            timeframe = 'MonthToDate'
                        }
                        kpis        = @()
                        pivots      = @()
                    }
                }
            }
        }
    }
}

function New-MarkdownTile {
    param([string]$id, [string]$content, [int]$x, [int]$y, [int]$colSpan, [int]$rowSpan)
    return @{
        position = New-Position $x $y $colSpan $rowSpan
        metadata = @{
            type    = 'Extension/HubsExtension/PartType/MarkdownPart'
            inputs  = @()
            settings = @{
                content = @{
                    settings = @{
                        content  = $content
                        title    = ''
                        subtitle = ''
                    }
                }
            }
        }
    }
}

function New-BudgetTile {
    param([int]$x, [int]$y)
    return @{
        position = New-Position $x $y 12 2
        metadata = @{
            type    = 'Extension/Microsoft_Azure_CostManagement/PartType/BudgetsPart'
            inputs  = @(
                @{ name = 'id'; value = $SCOPE }
            )
            settings = @{
                content = @{
                    scope             = $SCOPE
                    budgetDisplayMode = 'CurrentMonthActualSpend'
                }
            }
        }
    }
}

# ── markdown header content ────────────────────────────────────────────────────
$headerMd = @"
## FinOps – EsDAICoESub Cost Dashboard
**Scope**: EsDAICoESub (d2d4e571-e0f2-4f6c-901a-f88f7669bcba)
**ADX**: [Open in Data Explorer](https://dataexplorer.azure.com/clusters/marcofinopsadx.canadacentral/databases/finopsdb)
**Cost Analysis**: [Open in Portal](https://portal.azure.com/#@hrsdc-rhdcc.gc.ca/resource/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/costmanagement/costanalysis)

Key tag dimensions: ``ssc_cbrid`` · ``fin_financialauthority`` · ``environment`` · ``owner`` · ``project`` · ``sec_classification``
"@

# ── build lens parts ──────────────────────────────────────────────────────────
$sandboxFilter = @{
    and = @(
        @{
            tags = @{
                name     = 'project'
                operator = 'In'
                values   = @('GHCP-Sandbox')
            }
        }
    )
}

# Parts must be a JSON array (not an object with numeric keys)
$partsArray = @(
    (New-MarkdownTile -id '0' -content $headerMd -x 0 -y 0 -colSpan 12 -rowSpan 2),

    (New-CostTile -id '1' -x 0 -y 2 `
        -title 'Cost by SSC Billing Code (MTD)' `
        -groupTagKey 'ssc_cbrid'),

    (New-CostTile -id '2' -x 6 -y 2 `
        -title 'Cost by Financial Authority (MTD)' `
        -groupTagKey 'fin_financialauthority'),

    (New-CostTile -id '3' -x 0 -y 6 `
        -title 'Cost by Environment – GHCP-Sandbox (MTD)' `
        -groupTagKey 'environment' `
        -filter $sandboxFilter),

    (New-CostTile -id '4' -x 6 -y 6 `
        -title 'Cost by Owner (MTD)' `
        -groupTagKey 'owner'),

    (New-BudgetTile -x 0 -y 10)
)

# ── assemble full dashboard body ──────────────────────────────────────────────
# lenses must be a JSON array; parts inside each lens must also be a JSON array
$body = @{
    location = 'canadacentral'
    tags     = @{
        project            = 'GHCP-Sandbox'
        owner              = 'Marco Presta'
        environment        = 'Dev'
        sec_classification = 'Protected-A'
    }
    properties = @{
        lenses   = @(
            @{
                order = 0
                parts = $partsArray
            }
        )
        metadata = @{
            model = @{
                timeRange = @{
                    value = @{ relative = @{ duration = 24; timeUnit = 1 } }
                    type  = 'MsPortalFx.Composition.Configuration.ValueTypes.TimeRange'
                }
            }
        }
    }
}

$bodyJson = $body | ConvertTo-Json -Depth 30 -Compress

Write-Log "PUT dashboard: $DashboardName  →  $ResourceGroup"

if ($WhatIf) {
    Write-Host ($body | ConvertTo-Json -Depth 30) -ForegroundColor DarkGray
    exit 0
}

$tmp = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmp, $bodyJson, [System.Text.Encoding]::UTF8)

try {
    $resp = az rest `
        --method  PUT `
        --url     $URL `
        --body    "@$tmp" `
        --headers "Content-Type=application/json" `
        | ConvertFrom-Json

    if ($null -ne $resp.id) {
        Write-Log "Dashboard created: $($resp.id)" OK

        $tenant = 'hrsdc-rhdcc.gc.ca'
        Write-Host ''
        Write-Log 'Open dashboard in portal:' INFO
        Write-Host "  https://portal.azure.com/#@$tenant/dashboard/arm$($resp.id)" -ForegroundColor Green
    } else {
        Write-Log "Unexpected response: $($resp | ConvertTo-Json -Compress)" WARN
    }
} catch {
    Write-Log "FAILED: $_" ERROR
    exit 1
} finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}
