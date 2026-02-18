#!/usr/bin/env pwsh
<#$
.SYNOPSIS
Configure EsPAICoESub (Production) subscription cost export to FinOps Hub storage.

.DESCRIPTION
Creates or updates a subscription-level Cost Management export for EsPAICoESub
using the Azure REST helper functions in 18-azure-best/02-cost-management.
The export writes daily ActualCost CSV files into the FinOps storage account
marcosandboxfinopshub in the EsDAICoE-Sandbox resource group.

This script assumes:
- You have Reader + Cost Management Contributor on EsPAICoESub.
- You have Storage Blob Data Contributor on the target storage account.
- A subscription Owner/Contributor has already registered
  Microsoft.CostManagementExports for EsPAICoESub.

It is safe to run multiple times; the export will be created or updated
idempotently.

.PARAMETER SubscriptionId
Target subscription ID (default: EsPAICoESub).

.PARAMETER ExportName
Name of the Cost Management export resource.

.PARAMETER StorageResourceGroup
Resource group containing marcosandboxfinopshub.

.PARAMETER StorageAccount
Target storage account for cost exports.

.PARAMETER ContainerName
Blob container that will receive the export files.

.PARAMETER RootFolderPath
Root folder path inside the container for this subscription.

.PARAMETER TriggerImmediately
If set, trigger an immediate export run after creation.

.EXAMPLE
# Configure export with defaults and trigger first run
./Configure-EsPAICoESub-CostExport.ps1 -TriggerImmediately

.EXAMPLE
# Configure export but let the scheduled run execute at midnight UTC
./Configure-EsPAICoESub-CostExport.ps1
#>

param(
    [string]$SubscriptionId = "802d84ab-3189-4221-8453-fcc30c8dc8ea",  # EsPAICoESub (Production)
    [string]$ExportName = "EsPAICoESub-Daily",
    [string]$StorageResourceGroup = "EsDAICoE-Sandbox",
    [string]$StorageAccount = "marcosandboxfinopshub",
    [string]$ContainerName = "costs",
    [string]$RootFolderPath = "EsPAICoESub",
    [switch]$TriggerImmediately
)

# Ensure UTF-8 output on Windows
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

$scriptStartTime = Get-Date

Write-Host "" 
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "EsPAICoESub (Production) Cost Export Configuration" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Started: $($scriptStartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
Write-Host "" 

Write-Host "[INFO] Parameters" -ForegroundColor Cyan
Write-Host "  SubscriptionId       : $SubscriptionId" -ForegroundColor Gray
Write-Host "  ExportName           : $ExportName" -ForegroundColor Gray
Write-Host "  StorageResourceGroup : $StorageResourceGroup" -ForegroundColor Gray
Write-Host "  StorageAccount       : $StorageAccount" -ForegroundColor Gray
Write-Host "  ContainerName        : $ContainerName" -ForegroundColor Gray
Write-Host "  RootFolderPath       : $RootFolderPath" -ForegroundColor Gray
Write-Host "  TriggerImmediately   : $TriggerImmediately" -ForegroundColor Gray
Write-Host "" 

# Resolve Azure-REST-Functions.ps1 relative to this script
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$restModulePath = Join-Path $scriptRoot "..\..\18-azure-best\02-cost-management\Azure-REST-Functions.ps1"

if (-not (Test-Path -Path $restModulePath)) {
    Write-Host "[ERROR] Azure-REST-Functions.ps1 not found at expected path:" -ForegroundColor Red
    Write-Host "        $restModulePath" -ForegroundColor Red
    Write-Host "[HINT] Run from the eva-foundation repo where 14-az-finops and 18-azure-best are siblings." -ForegroundColor Yellow
    exit 1
}

Write-Host "[STEP 1/3] Importing Azure REST helper functions" -ForegroundColor Cyan
try {
    . $restModulePath
    Write-Host "  [PASS] Azure-REST-Functions.ps1 imported" -ForegroundColor Green
}
catch {
    Write-Host "  [ERROR] Failed to import Azure-REST-Functions.ps1" -ForegroundColor Red
    Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host "" 

Write-Host "[STEP 2/3] Validating Azure context and provider registration" -ForegroundColor Cyan

# Verify az login context
try {
    $currentSub = az account show --query "id" -o tsv 2>$null
}
catch {
    $currentSub = $null
}

if (-not $currentSub) {
    Write-Host "  [ERROR] Could not read current Azure account. Run 'az login' first." -ForegroundColor Red
    exit 1
}

Write-Host "  [INFO] Current Azure subscription from az: $currentSub" -ForegroundColor Gray

# Check Microsoft.CostManagement registration state (NOT CostManagementExports)
# The REST API uses Microsoft.CostManagement/exports endpoint
$providerState = $null
try {
    $providerState = az provider show --namespace Microsoft.CostManagement --query "registrationState" -o tsv 2>$null
}
catch {
    $providerState = $null
}

if ($providerState -ne "Registered") {
    Write-Host "  [ERROR] Resource provider Microsoft.CostManagement is not registered for this tenant/subscription." -ForegroundColor Red
    Write-Host "" 
    Write-Host "  Ask a subscription Owner or Contributor on EsPAICoESub to run:" -ForegroundColor Yellow
    Write-Host "    az account set --subscription $SubscriptionId" -ForegroundColor Gray
    Write-Host "    az provider register --namespace Microsoft.CostManagement" -ForegroundColor Gray
    Write-Host "" 
    Write-Host "  After the provider shows as Registered, rerun this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "  [PASS] Microsoft.CostManagement is registered" -ForegroundColor Green
Write-Host "" 

Write-Host "[STEP 3/3] Creating or updating Cost Management export" -ForegroundColor Cyan

# Build storage account resource ID
$storageAccountId = "/subscriptions/$SubscriptionId/resourceGroups/$StorageResourceGroup/providers/Microsoft.Storage/storageAccounts/$StorageAccount"
Write-Host "  [INFO] StorageAccountId: $storageAccountId" -ForegroundColor Gray

$exportParams = @{
    SubscriptionId   = $SubscriptionId
    ExportName       = $ExportName
    StorageAccountId = $storageAccountId
    ContainerName    = $ContainerName
    RootFolderPath   = $RootFolderPath
}

if ($TriggerImmediately) {
    $exportParams.TriggerImmediately = $true
}

try {
    $export = New-CostManagementExport @exportParams

    Write-Host "" 
    Write-Host "[SUCCESS] EsPAICoESub (Production) export configured" -ForegroundColor Green
    Write-Host "  Export Name : $ExportName" -ForegroundColor Gray
    Write-Host "  Container   : $ContainerName/$RootFolderPath" -ForegroundColor Gray
    Write-Host "  Storage     : $StorageAccount ($StorageResourceGroup)" -ForegroundColor Gray
    Write-Host "" 
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1) Wait 10-15 minutes for the first export to land." -ForegroundColor Gray
    Write-Host "  2) Verify blobs under: $ContainerName/$RootFolderPath" -ForegroundColor Gray
    Write-Host "  3) Use existing az-finops ingestion scripts to move data into raw/ and processed/." -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Failed to create or update Cost Management export" -ForegroundColor Red
    Write-Host "  Message: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

$scriptEndTime = Get-Date
$duration = (New-TimeSpan -Start $scriptStartTime -End $scriptEndTime).TotalSeconds
Write-Host "" 
Write-Host "[INFO] Completed in $([Math]::Round($duration,2)) seconds" -ForegroundColor Gray
