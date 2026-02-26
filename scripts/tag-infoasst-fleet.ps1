<#
.SYNOPSIS
    Tags all infoasst-* resource groups and their child resources with environment,
    project, ssc_cbrid, and fin_financialauthority tags using name-based pattern matching.

.DESCRIPTION
    Uses az tag update --operation Merge (non-destructive — preserves existing tags).
    Derives 'environment' from the RG name suffix:
        *-dev*    → Dev
        hccld2    → Dev  (secure-mode dev)
        *-stg*    → Stg

    Tags applied:
        environment              = Dev | Stg
        project                  = InformationAssistant
        ssc_cbrid                = 2133
        fin_financialauthority   = todd.whitley@hrsdc-rhdcc.gc.ca

.PARAMETER RgName
    Process only this specific RG (e.g. infoasst-dev1). Omit to process all.

.PARAMETER WhatIf
    Dry-run: show what would be tagged, no changes applied.

.PARAMETER SkipResources
    Only tag RGs, skip child resources.

.EXAMPLE
    .\tag-infoasst-fleet.ps1 -RgName infoasst-dev1
    .\tag-infoasst-fleet.ps1 -WhatIf
    .\tag-infoasst-fleet.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RgName,
    [switch]$SkipResources
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'   # az writes to stderr on warnings; don't let that terminate the pipeline

$SUB = 'd2d4e571-e0f2-4f6c-901a-f88f7669bcba'

# Resource types that cannot be tagged (sub-resources, extension resources)
$SKIP_TYPES = @(
    'Microsoft.Network/privateDnsZones/virtualNetworkLinks'
    'Microsoft.Network/privateDnsZones/A'
    'Microsoft.Network/privateDnsZones/SOA'
    'microsoft.alertsmanagement/smartDetectorAlertRules'
)

# ── tag constants ──────────────────────────────────────────────────────────────
$COMMON_TAGS = @{
    project                = 'InformationAssistant'
    ssc_cbrid              = '2133'
    fin_financialauthority = 'todd.whitley@hrsdc-rhdcc.gc.ca'
}

# ── environment resolver ───────────────────────────────────────────────────────
function Get-EnvValue {
    param([string]$RgName)
    if ($RgName -match '-dev' -or $RgName -match 'hccld2') { return 'Dev' }
    if ($RgName -match '-stg')                              { return 'Stg' }
    return $null   # unknown — will warn
}

# ── merge helper ──────────────────────────────────────────────────────────────
function Invoke-TagMerge {
    param(
        [string]$ResourceId,
        [hashtable]$Tags,
        [string]$Label
    )
    $tagArgs = ($Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '

    if ($PSCmdlet.ShouldProcess($Label, "az tag update --operation Merge [$tagArgs]")) {
        try {
            # Build tags as array of "key=value" strings (required for external az CLI)
            $tagPairs = $Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }

            az tag update `
                --operation Merge `
                --resource-id $ResourceId `
                --tags @tagPairs `
                --subscription $SUB `
                --output none 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "  FAILED: $Label"
            } else {
                Write-Host "  OK  $Label" -ForegroundColor Green
            }
        } catch {
            Write-Warning "  ERROR on $Label`: $_"
        }
    } else {
        Write-Host "  WHATIF  $Label  [$tagArgs]" -ForegroundColor Cyan
    }
}

# ── main ──────────────────────────────────────────────────────────────────────
Write-Host "`n=== infoasst fleet tagger ===" -ForegroundColor Yellow
Write-Host "Subscription : $SUB"
Write-Host "Mode         : $(if ($WhatIfPreference) { 'DRY-RUN' } else { 'LIVE' })`n"

# 1. enumerate infoasst-* RGs (optionally scoped to one)
$rgs = az group list --subscription $SUB -o json |
    ConvertFrom-Json |
    Where-Object { $_.name -match '^infoasst' }

if ($RgName) {
    $rgs = $rgs | Where-Object { $_.name -eq $RgName }
    if (-not $rgs) { Write-Error "RG '$RgName' not found or not an infoasst-* group."; exit 1 }
}

Write-Host "Found $($rgs.Count) infoasst-* resource groups`n"

$stats = @{ rgs = 0; resources = 0; warnings = 0 }

foreach ($rg in $rgs) {
    $env = Get-EnvValue -RgName $rg.name

    if (-not $env) {
        Write-Warning "Cannot determine environment for '$($rg.name)' — skipping"
        $stats.warnings++
        continue
    }

    $tags = $COMMON_TAGS + @{ environment = $env }

    Write-Host "── $($rg.name)  →  environment=$env" -ForegroundColor Magenta

    # 2. tag the RG itself
    Invoke-TagMerge -ResourceId $rg.id -Tags $tags -Label "RG: $($rg.name)"
    $stats.rgs++

    if ($SkipResources) { continue }

    # 3. tag every child resource in the RG
    $children = az resource list `
        --resource-group $rg.name `
        --subscription $SUB `
        -o json | ConvertFrom-Json

    Write-Host "  $($children.Count) child resources"

    foreach ($res in $children) {
        # Skip resource types that don't support tagging
        if ($SKIP_TYPES -contains $res.type) {
            Write-Host "  SKIP  $($res.type)/$($res.name)" -ForegroundColor DarkGray
            continue
        }
        Invoke-TagMerge `
            -ResourceId $res.id `
            -Tags $tags `
            -Label "$($res.type)/$($res.name)"
        $stats.resources++
    }

    Write-Host ""
}

# ── summary ───────────────────────────────────────────────────────────────────
Write-Host "`n=== Summary ===" -ForegroundColor Yellow
Write-Host "  RGs       tagged : $($stats.rgs)"
Write-Host "  Resources tagged : $($stats.resources)"
if ($stats.warnings -gt 0) {
    Write-Host "  Warnings         : $($stats.warnings)" -ForegroundColor Yellow
}
if ($WhatIfPreference) {
    Write-Host "`nDry-run complete. Re-run without -WhatIf to apply." -ForegroundColor Cyan
} else {
    Write-Host "`nDone." -ForegroundColor Green
}
