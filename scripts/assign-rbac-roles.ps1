# assign-rbac-roles.ps1
# Phase 2 Task 2.2.1 - Assign RBAC roles to mi-finops-adf managed identity
# Run AFTER deploying both adx-cluster.bicep and managed-identity.bicep
#
# Usage:
#   .\assign-rbac-roles.ps1
#   .\assign-rbac-roles.ps1 -WhatIf   <- preview mode

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroup     = "EsDAICoE-Sandbox",
    [string]$StorageAccount    = "marcosandboxfinopshub",
    [string]$SubscriptionId    = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba",
    [string]$IdentityName      = "mi-finops-adf",
    [string]$AdxClusterName    = "marcofinopsadx",
    [string]$AdxDatabase       = "finopsdb"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== FinOps Hub Phase 2 - RBAC Assignment ===" -ForegroundColor Cyan
Write-Host "Resource Group : $ResourceGroup"
Write-Host "Storage Account: $StorageAccount"
Write-Host "Identity       : $IdentityName"
Write-Host ""

# Ensure correct subscription
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription $SubscriptionId" }

# Get managed identity principal ID
Write-Host "[1/4] Getting managed identity principal ID..." -ForegroundColor Yellow
$miJson = az identity show --name $IdentityName --resource-group $ResourceGroup -o json 2>&1
if ($LASTEXITCODE -ne 0) { throw "Managed identity '$IdentityName' not found. Deploy managed-identity.bicep first." }
$mi = $miJson | ConvertFrom-Json
$principalId = $mi.principalId
$clientId    = $mi.clientId
Write-Host "  Principal ID: $principalId"
Write-Host "  Client ID   : $clientId"

# Role 1: Storage Blob Data Contributor on marcosandboxfinopshub
Write-Host "[2/4] Assigning Storage Blob Data Contributor..." -ForegroundColor Yellow
$storageScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Storage/storageAccounts/$StorageAccount"
$existing1 = az role assignment list --assignee $principalId --role "Storage Blob Data Contributor" --scope $storageScope -o json 2>&1 | ConvertFrom-Json
if ($existing1.Count -gt 0) {
    Write-Host "  [SKIP] Already assigned."
} else {
    if ($PSCmdlet.ShouldProcess($storageScope, "Assign Storage Blob Data Contributor")) {
        az role assignment create `
            --assignee $principalId `
            --role "Storage Blob Data Contributor" `
            --scope $storageScope `
            -o none
        if ($LASTEXITCODE -ne 0) { throw "Failed to assign Storage Blob Data Contributor." }
        Write-Host "  [OK] Assigned."
    }
}

# Role 2: Contributor on ADF (so mi can be used by ADF pipelines)
Write-Host "[3/4] Assigning Contributor on ADF factory..." -ForegroundColor Yellow
$adfScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.DataFactory/factories/marco-sandbox-finops-adf"
$existing2 = az role assignment list --assignee $principalId --role "Contributor" --scope $adfScope -o json 2>&1 | ConvertFrom-Json
if ($existing2.Count -gt 0) {
    Write-Host "  [SKIP] Already assigned."
} else {
    if ($PSCmdlet.ShouldProcess($adfScope, "Assign Contributor")) {
        az role assignment create `
            --assignee $principalId `
            --role "Contributor" `
            --scope $adfScope `
            -o none
        if ($LASTEXITCODE -ne 0) { Write-Warning "Could not assign Contributor on ADF - may need Owner permission. Continuing." }
        else { Write-Host "  [OK] Assigned." }
    }
}

# Role 3: ADX Database Ingestor - must be done via ADX principal assignment API
Write-Host "[4/4] Checking ADX cluster..." -ForegroundColor Yellow
$adxCluster = az resource show `
    --resource-group $ResourceGroup `
    --name $AdxClusterName `
    --resource-type "Microsoft.Kusto/clusters" `
    -o json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "ADX cluster '$AdxClusterName' not found yet. Run after ADX deployment."
    Write-Host ""
    Write-Host "== ADX Ingestor Assignment (run manually after ADX is ready) ==" -ForegroundColor Cyan
    Write-Host "az rest --method PUT \" 
    Write-Host "  --url `"https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Kusto/clusters/$AdxClusterName/databases/$AdxDatabase/principalAssignments/adf-ingestor?api-version=2023-08-15`" \"
    Write-Host "  --body '{`"properties`":{`"principalId`":`"$clientId`",`"principalType`":`"App`",`"role`":`"Ingestor`",`"tenantId`":`"9ed55846-8a81-4246-acd8-b1a01abfc0d1`"}}'"
} else {
    Write-Host "  ADX cluster found. Assigning Database Ingestor role via REST..."
    if ($PSCmdlet.ShouldProcess("$AdxClusterName/$AdxDatabase", "Assign ADX Ingestor to mi-finops-adf")) {
        $body = @{
            properties = @{
                principalId   = $clientId
                principalType = "App"
                role          = "Ingestor"
                tenantId      = "9ed55846-8a81-4246-acd8-b1a01abfc0d1"
            }
        } | ConvertTo-Json -Depth 5
        $url = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Kusto/clusters/$AdxClusterName/databases/$AdxDatabase/principalAssignments/adf-ingestor?api-version=2023-08-15"
        az rest --method PUT --url $url --body $body -o none
        if ($LASTEXITCODE -ne 0) { Write-Warning "ADX principal assignment failed. Check cluster status and retry." }
        else { Write-Host "  [OK] ADX Ingestor assigned." }
    }
}

Write-Host ""
Write-Host "=== RBAC Summary ===" -ForegroundColor Cyan
az role assignment list --assignee $principalId --query "[].{Role:roleDefinitionName, Scope:scope}" -o table 2>&1
Write-Host ""
Write-Host "[DONE] RBAC assignment complete." -ForegroundColor Green
Write-Host "  Next: Run create-schema.kql in ADX query editor at https://dataexplorer.azure.com/clusters/$AdxClusterName"
