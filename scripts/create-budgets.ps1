# EVA-FEATURE: F14-08
# EVA-STORY: F14-08-002
<#
.SYNOPSIS
    Create Consumption Budgets via REST API.

.DESCRIPTION
    Uses `az rest` to PUT two monthly budgets:
      1. FinOps-Budget-EsDAICoESub-Total
             Subscription-wide cap: CAD 700 000 / month.
             Notifies at 80 % (forecast) and 100 % (actual).
      2. FinOps-Budget-GHCP-Sandbox
             Scoped to resources tagged project=GHCP-Sandbox.
             Cap: CAD 50 000 / month.
             Notifies at 80 % (forecast) and 100 % (actual).

    Both budgets start on the first of the current month and expire
    2030-12-31. Adjust -TotalAmount / -SandboxAmount / -NotifyEmails
    as needed.

.PARAMETER SubscriptionId
    Target subscription. Defaults to EsDAICoESub.

.PARAMETER TotalAmount
    Monthly cap in CAD for the subscription-wide budget.
    REQUIRED – must be set by the Financial Authority. No default.

.PARAMETER SandboxAmount
    Monthly cap in CAD for the GHCP-Sandbox scoped budget.
    REQUIRED – must be set by the Financial Authority. No default.

.PARAMETER NotifyEmails
    Array of email addresses for budget alerts.

.PARAMETER WhatIf
    Print JSON bodies without calling the API.

.EXAMPLE
    .\create-budgets.ps1
    .\create-budgets.ps1 -TotalAmount 800000 -NotifyEmails @("you@dept.gc.ca")
#>

[CmdletBinding()]
param(
    [string]  $SubscriptionId = 'd2d4e571-e0f2-4f6c-901a-f88f7669bcba',
    [decimal] $TotalAmount    = 0,   # MUST be provided – no default (requires Financial Authority sign-off)
    [decimal] $SandboxAmount  = 0,   # MUST be provided – no default (requires Financial Authority sign-off)
    [string[]]$NotifyEmails   = @('marco.presta@hrsdc-rhdcc.gc.ca'),
    [switch]  $WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($TotalAmount -eq 0 -or $SandboxAmount -eq 0) {
    Write-Error "Budget amounts must be explicitly provided (-TotalAmount, -SandboxAmount). Values must be approved by the Financial Authority before creating budgets."
    exit 1
}

$API_VERSION = '2023-05-01'
$SCOPE       = "/subscriptions/$SubscriptionId"
$BASE_URL    = "https://management.azure.com$SCOPE/providers/Microsoft.Consumption/budgets"

# Budget window: start = first of this month, end = 2030-12-31
$startDate = (Get-Date -Day 1).ToString('yyyy-MM-01')
$endDate   = '2030-12-31'

function Write-Log($msg, $level = 'INFO') {
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $colour = switch ($level) { 'ERROR' { 'Red' } 'WARN' { 'Yellow' } 'OK' { 'Green' } default { 'Cyan' } }
    Write-Host "[$ts] [$level] $msg" -ForegroundColor $colour
}

# ── helper: build notification block ─────────────────────────────────────────
function New-Notifications([string[]]$emails) {
    return @{
        'Forecast_GreaterThan_80_Percent'  = @{
            enabled       = $true
            operator      = 'GreaterThan'
            threshold     = 80
            contactEmails = $emails
            thresholdType = 'Forecasted'
        }
        'Actual_GreaterThan_100_Percent'   = @{
            enabled       = $true
            operator      = 'GreaterThan'
            threshold     = 100
            contactEmails = $emails
            thresholdType = 'Actual'
        }
    }
}

# ── budget definitions ────────────────────────────────────────────────────────
$budgets = @(
    @{
        name   = 'FinOps-Budget-EsDAICoESub-Total'
        amount = $TotalAmount
        filter = @{}          # no filter = subscription-wide
    },
    @{
        name   = 'FinOps-Budget-GHCP-Sandbox'
        amount = $SandboxAmount
        filter = @{
            tags = @{
                name     = 'project'
                operator = 'In'
                values   = @('GHCP-Sandbox')
            }
        }
    }
)

# ── main loop ─────────────────────────────────────────────────────────────────
$results = @()

foreach ($b in $budgets) {
    $url = "$BASE_URL/$($b.name)?api-version=$API_VERSION"

    $properties = @{
        category   = 'Cost'
        amount     = $b.amount
        timeGrain  = 'Monthly'
        timePeriod = @{
            startDate = $startDate
            endDate   = $endDate
        }
        notifications = (New-Notifications -emails $NotifyEmails)
    }

    # Only add filter if it has content (subscription-wide budget needs no filter key)
    if ($b.filter.Count -gt 0) {
        $properties['filter'] = $b.filter
    }

    $body     = @{ properties = $properties }
    $bodyJson = $body | ConvertTo-Json -Depth 20 -Compress

    Write-Log "PUT $($b.name)  (CAD $($b.amount)/month)"

    if ($WhatIf) {
        Write-Host ($body | ConvertTo-Json -Depth 20) -ForegroundColor DarkGray
        $results += [PSCustomObject]@{ Budget = $b.name; Amount = $b.amount; Status = 'WhatIf' }
        continue
    }

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
            $results += [PSCustomObject]@{ Budget = $b.name; Amount = $b.amount; Status = 'OK'; Id = $resp.id }
        } else {
            Write-Log "  Unexpected: $($resp | ConvertTo-Json -Compress)" WARN
            $results += [PSCustomObject]@{ Budget = $b.name; Amount = $b.amount; Status = 'Unknown'; Id = '' }
        }
    } catch {
        Write-Log "  FAILED: $_" ERROR
        $results += [PSCustomObject]@{ Budget = $b.name; Amount = $b.amount; Status = 'Error'; Id = $_.ToString() }
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ''
Write-Log '─── Summary ──────────────────────────────────────────────────────' INFO
$results | Format-Table -AutoSize

# ── portal deep-link ─────────────────────────────────────────────────────────
$tenant = 'hrsdc-rhdcc.gc.ca'
Write-Host ''
Write-Log "Manage budgets in portal:" INFO
Write-Host "  https://portal.azure.com/#@$tenant/resource$SCOPE/costmanagement/budgets" -ForegroundColor Green
