# deploy-adf-artefacts.ps1
# Phase 2 Task 2.2.2-2.2.4 - Deploy ADF linked services, datasets, and pipeline
# via Azure Management REST API (no az datafactory extension required)
#
# Prerequisites:
#   - mi-finops-adf managed identity deployed (managed-identity.bicep)
#   - ADX cluster marcofinopsadx running
#   - assign-rbac-roles.ps1 completed
#
# Usage:
#   .\deploy-adf-artefacts.ps1
#   .\deploy-adf-artefacts.ps1 -WhatIf

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SubscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba",
    [string]$ResourceGroup  = "EsDAICoE-Sandbox",
    [string]$AdfName        = "marco-sandbox-finops-adf",
    [string]$ScriptsRoot    = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== ADF Artefacts Deployment ===" -ForegroundColor Cyan
Write-Host "Factory: $AdfName | RG: $ResourceGroup"
Write-Host ""

az account set --subscription $SubscriptionId

$baseUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.DataFactory/factories/$AdfName"
$apiVer  = "api-version=2018-06-01"

function Upsert-AdfResource {
    param(
        [string]$Type,     # linkedservices | datasets | pipelines
        [string]$Name,
        [string]$JsonFile
    )
    $url = "$baseUrl/$Type/${Name}?$apiVer"
    Write-Host "  Deploying $Type/$Name ..."
    if ($PSCmdlet.ShouldProcess("$Type/$Name", "PUT")) {
        # Use @file syntax so az rest reads JSON from disk (avoids PS string escaping issues)
        $result = az rest --method PUT --url $url --body "@$JsonFile" --headers "Content-Type=application/json" -o json 2>&1
        if ($LASTEXITCODE -ne 0 -or ($result -is [string] -and $result -match '"error"')) {
            throw "Failed to deploy $Type/$Name : $result"
        }
        Write-Host "  [OK] $Type/$Name"
    }
}

# ===========================================================================
# 1. Credential (managed identity reference)
# ===========================================================================
Write-Host "[1/4] Creating managed identity credential..." -ForegroundColor Yellow
$miResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-finops-adf"
$credFile = "$env:TEMP\adf-cred.json"
@"
{
  "name": "mi-finops-adf",
  "properties": {
    "type": "ManagedIdentity",
    "typeProperties": {
      "resourceId": "$miResourceId"
    }
  }
}
"@ | Set-Content $credFile -Encoding UTF8 -NoNewline

if ($PSCmdlet.ShouldProcess("credentials/mi-finops-adf", "PUT")) {
    $result = az rest --method PUT `
        --url "$baseUrl/credentials/mi-finops-adf?$apiVer" `
        --body "@$credFile" `
        --headers "Content-Type=application/json" `
        -o json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Credential mi-finops-adf registered."
    } else {
        Write-Warning "  Credential registration warning: $result"
    }
    Remove-Item $credFile -Force -ErrorAction SilentlyContinue
}

# ===========================================================================
# 2. Linked Services
# ===========================================================================
Write-Host "[2/4] Deploying linked services..." -ForegroundColor Yellow
$lsDir = Join-Path $ScriptsRoot "adf\linked-services"
Upsert-AdfResource -Type "linkedservices" -Name "ls_marcosandbox_blob"   -JsonFile (Join-Path $lsDir "ls_marcosandbox_blob.json")
Upsert-AdfResource -Type "linkedservices" -Name "ls_marcofinops_adx"     -JsonFile (Join-Path $lsDir "ls_marcofinops_adx.json")

# ===========================================================================
# 3. Datasets
# ===========================================================================
Write-Host "[3/4] Deploying datasets..." -ForegroundColor Yellow
$dsDir = Join-Path $ScriptsRoot "adf\datasets"
Upsert-AdfResource -Type "datasets" -Name "ds_blob_cost_csv"  -JsonFile (Join-Path $dsDir "ds_blob_cost_csv.json")
Upsert-AdfResource -Type "datasets" -Name "ds_adx_raw_costs"  -JsonFile (Join-Path $dsDir "ds_adx_raw_costs.json")

# ===========================================================================
# 4. Pipeline
# ===========================================================================
Write-Host "[4/4] Deploying pipeline..." -ForegroundColor Yellow
$pipeDir = Join-Path $ScriptsRoot "adf\pipelines"
Upsert-AdfResource -Type "pipelines" -Name "ingest-costs-to-adx" -JsonFile (Join-Path $pipeDir "ingest-costs-to-adx.json")

# ===========================================================================
# Summary
# ===========================================================================
Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "ADF Studio: https://adf.azure.com/authoring/$AdfName"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open ADF Studio and verify linked services / test connections"
Write-Host "  2. Create Storage Event trigger pointing to raw/costs/**/*.csv.gz"  
Write-Host "  3. Associate trigger with pipeline ingest-costs-to-adx"
Write-Host "  4. Run create-schema.kql in ADX query editor: https://dataexplorer.azure.com/clusters/marcofinopsadx"
Write-Host "  5. Test pipeline manually with a sample blob URL"
Write-Host ""
Write-Host "[DONE] ADF artefacts deployed." -ForegroundColor Green
