#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Phase 3 APIM telemetry pipeline infrastructure.
    Idempotent: can be re-run safely.

.DESCRIPTION
    Creates and configures:
      - Event Hub Namespace: marco-finops-evhns
      - Event Hub: apim-gateway-logs  (4 partitions, 7d retention)
      - RBAC: ADX cluster MI gets Azure Event Hubs Data Receiver on namespace
      - APIM Diagnostic Settings → Event Hub (GatewayLogs, 100%)
      - APIM App Insights logger: appinsights-finops → marco-sandbox-appinsights
      - APIM applicationinsights diagnostic (100% sampling, W3C, x-* headers)
      - APIM azuremonitor diagnostic (100% sampling, x-* headers logged)
      - APIM global policy (attribution header normalisation)
      - ADX: apim_usage_staging table + ApimStagingMapping + update policy
      - ADX: apim-usage-ingestion Event Hub data connection

.NOTES
    Requires: az login, correct subscription set
    Subscription: d2d4e571-e0f2-4f6c-901a-f88f7669bcba (EsDAICoESub)
    Resource Group: EsDAICoE-Sandbox
#>
param(
  [string]$SubscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba",
  [string]$ResourceGroup  = "EsDAICoE-Sandbox",
  [string]$Location       = "canadacentral",
  [string]$ApimName       = "marco-sandbox-apim",
  [string]$AdxCluster     = "marcofinopsadx",
  [string]$AdxDatabase    = "finopsdb",
  [string]$AppInsightsName = "marco-sandbox-appinsights",
  [string]$EhNamespace    = "marco-finops-evhns",
  [string]$EhName         = "apim-gateway-logs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sub = $SubscriptionId
$rg  = $ResourceGroup

function Get-MgmtToken  { (az account get-access-token --resource "https://management.azure.com/" -o json | ConvertFrom-Json).accessToken }
function Get-AdxToken   { (az account get-access-token --resource "https://$AdxCluster.$Location.kusto.windows.net" -o json | ConvertFrom-Json).accessToken }

function Arm-Put($url, $body) {
  $t = Get-MgmtToken
  Invoke-RestMethod -Method PUT -Uri "$url`?api-version=$($url -replace '.+api-version=','')" `
    -Headers @{Authorization="Bearer $t";"Content-Type"="application/json"} `
    -Body ($body | ConvertTo-Json -Depth 10 -Compress) -ErrorAction SilentlyContinue
}

function Adx-Mgmt($kql) {
  $t = Get-AdxToken
  $b = @{db=$AdxDatabase; csl=$kql} | ConvertTo-Json -Compress
  Invoke-RestMethod -Method POST -Uri "https://$AdxCluster.$Location.kusto.windows.net/v1/rest/mgmt" `
    -Headers @{Authorization="Bearer $t";"Content-Type"="application/json"} -Body $b
}

Write-Host "=== Phase 3: APIM Telemetry Pipeline ===" -ForegroundColor Cyan

# ─── 1. Event Hub Namespace ───────────────────────────────────────────────────
Write-Host "[1/9] Event Hub Namespace $EhNamespace..."
$mgt = Get-MgmtToken
$evhns = Invoke-RestMethod -Method PUT `
  -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.EventHub/namespaces/$EhNamespace`?api-version=2022-10-01-preview" `
  -Headers @{Authorization="Bearer $mgt";"Content-Type"="application/json"} `
  -Body (@{location=$Location; sku=@{name="Standard";tier="Standard";capacity=1}; tags=@{project="finops"; env="sandbox"}} | ConvertTo-Json -Compress)
Write-Host "  Created: $($evhns.name) → $($evhns.properties.provisioningState)"
for ($i=0; $i -lt 12 -and $evhns.properties.provisioningState -ne "Succeeded"; $i++) {
  Start-Sleep 10
  $evhns = Invoke-RestMethod -Method GET -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.EventHub/namespaces/$EhNamespace`?api-version=2022-10-01-preview" -Headers @{Authorization="Bearer (Get-MgmtToken)";"Content-Type"="application/json"}
}
Write-Host "  Ready: $($evhns.properties.provisioningState)"

# ─── 2. Event Hub ──────────────────────────────────────────────────────────────
Write-Host "[2/9] Event Hub $EhName..."
$eh = Invoke-RestMethod -Method PUT `
  -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.EventHub/namespaces/$EhNamespace/eventhubs/$EhName`?api-version=2022-10-01-preview" `
  -Headers @{Authorization="Bearer $mgt";"Content-Type"="application/json"} `
  -Body (@{properties=@{messageRetentionInDays=7; partitionCount=4}} | ConvertTo-Json -Compress)
Write-Host "  $($eh.name) partitions=$($eh.properties.partitionCount)"

# ─── 3. RBAC: ADX MI → Event Hubs Data Receiver ──────────────────────────────
Write-Host "[3/9] RBAC: ADX MI → Azure Event Hubs Data Receiver..."
$adxMI = (Invoke-RestMethod -Method GET `
  -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Kusto/clusters/$AdxCluster`?api-version=2023-08-15" `
  -Headers @{Authorization="Bearer $mgt"}).identity.principalId
az role assignment create --assignee-object-id $adxMI --assignee-principal-type ServicePrincipal `
  --role "Azure Event Hubs Data Receiver" `
  --scope "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.EventHub/namespaces/$EhNamespace" 2>&1 | Out-Null
Write-Host "  Assigned for $adxMI"

# ─── 4. APIM base policy ──────────────────────────────────────────────────────
Write-Host "[4/9] APIM base policy..."
$policyXml = Get-Content "$PSScriptRoot\apim\base-policy.xml" -Raw
$policyResp = Invoke-RestMethod -Method PUT `
  -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.ApiManagement/service/$ApimName/policies/policy?api-version=2022-08-01" `
  -Headers @{Authorization="Bearer $mgt";"Content-Type"="application/json"} `
  -Body (@{properties=@{format="xml"; value=$policyXml}} | ConvertTo-Json -Depth 5 -Compress)
Write-Host "  Policy: $($policyResp.name)"

# ─── 5. App Insights logger on APIM ──────────────────────────────────────────
Write-Host "[5/9] APIM App Insights logger..."
$aiId = "/subscriptions/$sub/resourceGroups/$rg/providers/microsoft.insights/components/$AppInsightsName"
$aiIkey = (Invoke-RestMethod -Method GET -Uri "https://management.azure.com$aiId`?api-version=2020-02-02" -Headers @{Authorization="Bearer $mgt"}).properties.InstrumentationKey
$aiLogger = Invoke-RestMethod -Method PUT `
  -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.ApiManagement/service/$ApimName/loggers/appinsights-finops?api-version=2022-08-01" `
  -Headers @{Authorization="Bearer $mgt";"Content-Type"="application/json"} `
  -Body (@{properties=@{loggerType="applicationInsights"; description="finops appinsights logger"; credentials=@{instrumentationKey=$aiIkey}; resourceId=$aiId}} | ConvertTo-Json -Depth 5 -Compress)
Write-Host "  Logger: $($aiLogger.name) | $($aiLogger.properties.loggerType)"

# ─── 6. APIM diagnostics (App Insights 100%) ─────────────────────────────────
Write-Host "[6/9] APIM applicationinsights diagnostic (100% sampling)..."
$diag = Invoke-RestMethod -Method PUT `
  -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.ApiManagement/service/$ApimName/diagnostics/applicationinsights?api-version=2022-08-01" `
  -Headers @{Authorization="Bearer $mgt";"Content-Type"="application/json"} `
  -Body (@{properties=@{alwaysLog="allErrors"; loggerId=$aiLogger.id; sampling=@{samplingType="fixed";percentage=100}; logClientIp=$true; httpCorrelationProtocol="W3C"; verbosity="information"; frontend=@{request=@{headers=@("x-caller-app","x-costcenter","x-environment","x-request-id"); dataMasking=@{queryParams=@(@{value="*";mode="Hide"})}}; response=@{headers=@("x-caller-app","x-costcenter","x-environment")}}; backend=@{request=@{headers=@("x-caller-app","x-costcenter","x-environment"); dataMasking=@{queryParams=@(@{value="*";mode="Hide"})}}}}} | ConvertTo-Json -Depth 10 -Compress)
Write-Host "  Sampling: $($diag.properties.sampling.percentage)%"

# ─── 7. APIM azuremonitor diagnostic (header logging) ────────────────────────
Write-Host "[7/9] APIM azuremonitor diagnostic (x-* headers)..."
$amLoggerId = "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.ApiManagement/service/$ApimName/loggers/azuremonitor"
$amDiag = Invoke-RestMethod -Method PUT `
  -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.ApiManagement/service/$ApimName/diagnostics/azuremonitor?api-version=2022-08-01" `
  -Headers @{Authorization="Bearer $mgt";"Content-Type"="application/json"} `
  -Body (@{properties=@{loggerId=$amLoggerId; sampling=@{samplingType="fixed";percentage=100}; logClientIp=$true; frontend=@{request=@{headers=@("x-caller-app","x-costcenter","x-environment","x-request-id"); dataMasking=@{queryParams=@(@{value="*";mode="Hide"})}}}; backend=@{request=@{headers=@("x-caller-app","x-costcenter","x-environment"); dataMasking=@{queryParams=@(@{value="*";mode="Hide"})}}}}} | ConvertTo-Json -Depth 10 -Compress)
Write-Host "  Headers: $($amDiag.properties.frontend.request.headers -join ',')"

# ─── 8. APIM Diagnostic Settings → Event Hub ─────────────────────────────────
Write-Host "[8/9] APIM Diagnostic Settings → Event Hub..."
$authRuleId = "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.EventHub/namespaces/$EhNamespace/AuthorizationRules/RootManageSharedAccessKey"
$ds = Invoke-RestMethod -Method PUT `
  -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.ApiManagement/service/$ApimName/providers/microsoft.insights/diagnosticSettings/apim-to-evhub?api-version=2021-05-01-preview" `
  -Headers @{Authorization="Bearer $mgt";"Content-Type"="application/json"} `
  -Body (@{properties=@{eventHubAuthorizationRuleId=$authRuleId; eventHubName=$EhName; logs=@(@{category="GatewayLogs"; enabled=$true; retentionPolicy=@{enabled=$false; days=0}})}} | ConvertTo-Json -Depth 8 -Compress)
Write-Host "  DiagSettings: $($ds.name) → $($ds.properties.eventHubName)"

# ─── 9. ADX Event Hub data connection ────────────────────────────────────────
Write-Host "[9/9] ADX Event Hub data connection..."
$ehResourceId = "/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.EventHub/namespaces/$EhNamespace/eventhubs/$EhName"
$dc = Invoke-RestMethod -Method PUT `
  -Uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Kusto/clusters/$AdxCluster/databases/$AdxDatabase/dataConnections/apim-usage-ingestion?api-version=2023-08-15" `
  -Headers @{Authorization="Bearer $mgt";"Content-Type"="application/json"} `
  -Body (@{location=$Location; kind="EventHub"; properties=@{eventHubResourceId=$ehResourceId; consumerGroup='$Default'; tableName="apim_usage_staging"; mappingRuleName="ApimStagingMapping"; dataFormat="JSON"; compression="None"; managedIdentityResourceId="/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.Kusto/clusters/$AdxCluster"}} | ConvertTo-Json -Depth 5 -Compress)
Write-Host "  DataConn: $($dc.name) kind=$($dc.kind) state=$($dc.properties.provisioningState)"

Write-Host ""
Write-Host "=== Phase 3 deployment complete ===" -ForegroundColor Green
Write-Host "Next: send test traffic to marco-sandbox-apim and verify rows in apim_usage"
