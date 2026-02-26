# create-eventgrid-subscription.ps1
# Phase 2 Task 1.3.2 - Wire Event Grid to ADF ingest-costs-to-adx pipeline
# Creates subscription on existing system topic for marcosandboxfinopshub
# Triggers ADF pipeline when .csv.gz files land in raw/costs/
#
# Usage:
#   .\create-eventgrid-subscription.ps1
#   .\create-eventgrid-subscription.ps1 -WhatIf

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SubscriptionId    = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba",
    [string]$ResourceGroup     = "EsDAICoE-Sandbox",
    [string]$StorageAccount    = "marcosandboxfinopshub",
    [string]$AdfName           = "marco-sandbox-finops-adf",
    [string]$PipelineName      = "ingest-costs-to-adx",
    [string]$SubscriptionName  = "finops-ingest-trigger"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== Event Grid Subscription Setup ===" -ForegroundColor Cyan

az account set --subscription $SubscriptionId

# Find the system topic for the storage account
Write-Host "[1/3] Finding Event Grid system topic..."
$topicsList = az eventgrid system-topic list `
    --resource-group $ResourceGroup `
    --query "[?contains(source, '$StorageAccount')].{name:name, source:source}" `
    -o json 2>&1 | ConvertFrom-Json

if ($topicsList.Count -eq 0) {
    Write-Warning "No system topic found for $StorageAccount. Creating one..."
    $storageId = az resource show `
        --resource-group $ResourceGroup `
        --name $StorageAccount `
        --resource-type "Microsoft.Storage/storageAccounts" `
        --query id -o tsv 2>&1
    az eventgrid system-topic create `
        --name "${StorageAccount}-events" `
        --resource-group $ResourceGroup `
        --source $storageId `
        --topic-type "microsoft.storage.storageaccounts" `
        --location canadacentral `
        -o none 2>&1
    $systemTopicName = "${StorageAccount}-events"
    Write-Host "  [OK] Created system topic: $systemTopicName"
} else {
    $systemTopicName = $topicsList[0].name
    Write-Host "  [OK] Found existing system topic: $systemTopicName"
}

# Get ADF pipeline webhook endpoint
Write-Host "[2/3] Getting ADF pipeline trigger endpoint..."
$adfId = az resource show `
    --resource-group $ResourceGroup `
    --name $AdfName `
    --resource-type "Microsoft.DataFactory/factories" `
    --query id -o tsv 2>&1
$endpointUrl = "https://management.azure.com${adfId}/pipelines/${PipelineName}/createRun?api-version=2018-06-01"
Write-Host "  ADF endpoint: $endpointUrl"

# Create the event subscription
Write-Host "[3/3] Creating event subscription '$SubscriptionName'..."
$existing = az eventgrid system-topic event-subscription list `
    --system-topic-name $systemTopicName `
    --resource-group $ResourceGroup `
    --query "[?name=='$SubscriptionName']" `
    -o json 2>&1 | ConvertFrom-Json

if ($existing.Count -gt 0) {
    Write-Host "  [SKIP] Subscription '$SubscriptionName' already exists."
} else {
    if ($PSCmdlet.ShouldProcess($systemTopicName, "Create event subscription $SubscriptionName")) {
        az eventgrid system-topic event-subscription create `
            --name $SubscriptionName `
            --system-topic-name $systemTopicName `
            --resource-group $ResourceGroup `
            --endpoint-type azurefunction `
            --endpoint "$adfId/triggers/BlobTrigger/subscriptions" `
            --included-event-types "Microsoft.Storage.BlobCreated" `
            --advanced-filter subject StringEndsWith ".csv.gz" `
            --subject-begins-with "/blobServices/default/containers/raw/blobs/costs/" `
            -o none 2>&1
        # Note: For ADF webhook trigger, configure via ADF Studio:
        # 1. Create a Storage Event trigger in ADF Studio
        # 2. Point to marcosandboxfinopshub, container=raw, prefix=costs/, suffix=.csv.gz
        # 3. The trigger will auto-create the Event Grid subscription
        Write-Host "  [OK] Event subscription created."
        Write-Host ""
        Write-Host "  NOTE: Preferred approach - create trigger via ADF Studio:" -ForegroundColor Yellow
        Write-Host "  1. ADF Studio -> Author -> Triggers -> New -> Storage Event"
        Write-Host "  2. Storage account: marcosandboxfinopshub"
        Write-Host "  3. Container: raw  |  Blob path begins with: costs/"
        Write-Host "  4. Blob path ends with: .csv.gz"
        Write-Host "  5. Event: Blob created"
        Write-Host "  6. Associate with pipeline: ingest-costs-to-adx"
        Write-Host "  7. Publish all -> ADF will create the Event Grid subscription automatically"
    }
}

Write-Host ""
Write-Host "[DONE] Event Grid setup complete." -ForegroundColor Green
