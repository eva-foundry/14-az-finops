#Requires -Version 5.1
<#
.SYNOPSIS
    Automated Azure inventory collection for FinOps Hub evidence gathering.

.DESCRIPTION
    This script collects comprehensive Azure resource metadata for marcosandbox FinOps 
    implementation. Outputs JSON files suitable for version control and comparison.
    
    Evidence artifacts are written to: tools/finops/out/
    
    Based on requirements from: docs/finops/05-evidence-pack.md

.PARAMETER SubscriptionIds
    Array of subscription IDs to inventory. Defaults to EsDAICoESub and EsPAICoESub.

.PARAMETER ResourceGroup
    Target resource group. Defaults to EsDAICoE-Sandbox.

.PARAMETER OutputDirectory
    Directory for JSON output files. Defaults to ./out/

.PARAMETER SkipADX
    Skip ADX cluster queries (useful if ADX not deployed yet).

.EXAMPLE
    .\az-inventory-finops.ps1
    
    Collects inventory with default parameters (both subscriptions, sandbox RG).

.EXAMPLE
    .\az-inventory-finops.ps1 -SkipADX
    
    Collects inventory but skips ADX queries (pre-deployment validation).

.NOTES
    Author: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)
    Date: 2026-02-17 08:20 AM ET
    Version: 1.0.0
    
    Prerequisites:
    - Azure CLI 2.50+ installed
    - Authenticated with professional account (marco.presta@hrsdc-rhdcc.gc.ca)
    - Minimum permission: Reader role on target subscriptions
    
    Duration: ~2-3 minutes for full inventory
#>

[CmdletBinding()]
param(
    [string[]]$SubscriptionIds = @(
        "d2d4e571-e0f2-4f6c-901a-f88f7669bcba",  # EsDAICoESub (dev/stage)
        "802d84ab-3189-4221-8453-fcc30c8dc8ea"   # EsPAICoESub (prod)
    ),
    
    [string]$ResourceGroup = "EsDAICoE-Sandbox",
    
    [string]$OutputDirectory = "./out",
    
    [switch]$SkipADX
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"  # Continue on non-critical errors

# ASCII-only output for enterprise Windows safety
$OutputEncoding = [System.Text.Encoding]::ASCII

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Evidence {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "Cyan"
    )
    Write-Host "[EVIDENCE] $Message" -ForegroundColor $Color
}

function Write-EvidenceError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Save-JsonOutput {
    param(
        [string]$FilePath,
        [object]$Data,
        [string]$Description
    )
    
    try {
        $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Evidence "Saved: $Description -> $FilePath" -Color Green
    }
    catch {
        Write-EvidenceError "Failed to save $Description : $_"
    }
}

function Test-AzureCLI {
    try {
        $version = az version --output json 2>$null | ConvertFrom-Json
        Write-Evidence "Azure CLI version: $($version.'azure-cli')"
        return $true
    }
    catch {
        Write-EvidenceError "Azure CLI not found or not authenticated. Run 'az login' first."
        return $false
    }
}

function Get-CurrentAzureAccount {
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-Evidence "Authenticated as: $($account.user.name)"
        Write-Evidence "Default subscription: $($account.name) ($($account.id))"
        return $account
    }
    catch {
        Write-EvidenceError "Failed to get current account. Run 'az login'."
        return $null
    }
}

# ============================================================================
# Inventory Collection Functions
# ============================================================================

function Get-StorageAccountInventory {
    param([string]$SubId)
    
    Write-Evidence "Collecting storage accounts..."
    
    try {
        $accounts = az storage account list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($accounts.Count) storage account(s)"
        return $accounts
    }
    catch {
        Write-EvidenceError "Failed to list storage accounts: $_"
        return @()
    }
}

function Get-StorageContainerInventory {
    param([string]$AccountName)
    
    Write-Evidence "Collecting containers for $AccountName..."
    
    try {
        $containers = az storage container list `
            --account-name $AccountName `
            --auth-mode login `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($containers.Count) container(s)"
        return $containers
    }
    catch {
        Write-EvidenceError "Failed to list containers for ${AccountName}: $_"
        return @()
    }
}

function Get-EventGridInventory {
    param([string]$SubId)
    
    Write-Evidence "Collecting Event Grid system topics..."
    
    try {
        $topics = az eventgrid system-topic list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($topics.Count) system topic(s)"
        return $topics
    }
    catch {
        Write-EvidenceError "Failed to list Event Grid topics: $_"
        return @()
    }
}

function Get-EventSubscriptions {
    param(
        [string]$SubId,
        [string]$TopicName
    )
    
    if ([string]::IsNullOrEmpty($TopicName)) {
        Write-Evidence "Skipping event subscriptions (no topic name provided)"
        return @()
    }
    
    Write-Evidence "Collecting event subscriptions for $TopicName..."
    
    try {
        $subscriptions = az eventgrid system-topic event-subscription list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --system-topic-name $TopicName `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($subscriptions.Count) event subscription(s)"
        return $subscriptions
    }
    catch {
        Write-EvidenceError "Failed to list event subscriptions: $_"
        return @()
    }
}

function Get-DataFactoryInventory {
    param([string]$SubId)
    
    Write-Evidence "Collecting Data Factory instances..."
    
    try {
        $factories = az datafactory list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($factories.Count) ADF instance(s)"
        return $factories
    }
    catch {
        Write-EvidenceError "Failed to list Data Factories: $_"
        return @()
    }
}

function Get-ADFPipelines {
    param(
        [string]$SubId,
        [string]$FactoryName
    )
    
    if ([string]::IsNullOrEmpty($FactoryName)) {
        Write-Evidence "Skipping ADF pipelines (no factory name provided)"
        return @()
    }
    
    Write-Evidence "Collecting ADF pipelines for $FactoryName..."
    
    try {
        $pipelines = az datafactory pipeline list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --factory-name $FactoryName `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($pipelines.Count) pipeline(s)"
        return $pipelines
    }
    catch {
        Write-EvidenceError "Failed to list ADF pipelines: $_"
        return @()
    }
}

function Get-ADFTriggers {
    param(
        [string]$SubId,
        [string]$FactoryName
    )
    
    if ([string]::IsNullOrEmpty($FactoryName)) {
        Write-Evidence "Skipping ADF triggers (no factory name provided)"
        return @()
    }
    
    Write-Evidence "Collecting ADF triggers for $FactoryName..."
    
    try {
        $triggers = az datafactory trigger list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --factory-name $FactoryName `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($triggers.Count) trigger(s)"
        return $triggers
    }
    catch {
        Write-EvidenceError "Failed to list ADF triggers: $_"
        return @()
    }
}

function Get-ADXInventory {
    param([string]$SubId)
    
    if ($SkipADX) {
        Write-Evidence "Skipping ADX inventory (SkipADX flag set)"
        return @()
    }
    
    Write-Evidence "Collecting ADX clusters..."
    
    try {
        $clusters = az kusto cluster list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($clusters.Count) ADX cluster(s)"
        return $clusters
    }
    catch {
        Write-EvidenceError "Failed to list ADX clusters: $_"
        return @()
    }
}

function Get-ADXDatabases {
    param(
        [string]$SubId,
        [string]$ClusterName
    )
    
    if ([string]::IsNullOrEmpty($ClusterName)) {
        Write-Evidence "Skipping ADX databases (no cluster name provided)"
        return @()
    }
    
    Write-Evidence "Collecting ADX databases for $ClusterName..."
    
    try {
        $databases = az kusto database list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --cluster-name $ClusterName `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($databases.Count) database(s)"
        return $databases
    }
    catch {
        Write-EvidenceError "Failed to list ADX databases: $_"
        return @()
    }
}

function Get-APIMInventory {
    param([string]$SubId)
    
    Write-Evidence "Collecting APIM instances..."
    
    try {
        $instances = az apim list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($instances.Count) APIM instance(s)"
        return $instances
    }
    catch {
        Write-EvidenceError "Failed to list APIM instances: $_"
        return @()
    }
}

function Get-APIMApis {
    param(
        [string]$SubId,
        [string]$ServiceName
    )
    
    if ([string]::IsNullOrEmpty($ServiceName)) {
        Write-Evidence "Skipping APIM APIs (no service name provided)"
        return @()
    }
    
    Write-Evidence "Collecting APIM APIs for $ServiceName..."
    
    try {
        $apis = az apim api list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --service-name $ServiceName `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($apis.Count) API(s)"
        return $apis
    }
    catch {
        Write-EvidenceError "Failed to list APIM APIs: $_"
        return @()
    }
}

function Get-APIMLoggers {
    param(
        [string]$SubId,
        [string]$ServiceName
    )
    
    if ([string]::IsNullOrEmpty($ServiceName)) {
        Write-Evidence "Skipping APIM loggers (no service name provided)"
        return @()
    }
    
    Write-Evidence "Collecting APIM loggers for $ServiceName..."
    
    try {
        $loggers = az apim logger list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --service-name $ServiceName `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($loggers.Count) logger(s)"
        return $loggers
    }
    catch {
        Write-EvidenceError "Failed to list APIM loggers: $_"
        return @()
    }
}

function Get-CostExports {
    param([string]$SubId)
    
    Write-Evidence "Collecting Cost Management exports for subscription $SubId..."
    
    try {
        $exports = az costmanagement export list `
            --scope "/subscriptions/$SubId" `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($exports.Count) export(s)"
        return $exports
    }
    catch {
        Write-EvidenceError "Failed to list cost exports: $_"
        return @()
    }
}

function Get-AppInsights {
    param([string]$SubId)
    
    Write-Evidence "Collecting Application Insights components..."
    
    try {
        $components = az monitor app-insights component list `
            --subscription $SubId `
            --resource-group $ResourceGroup `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($components.Count) App Insights component(s)"
        return $components
    }
    catch {
        Write-EvidenceError "Failed to list App Insights: $_"
        return @()
    }
}

function Get-RBACAssignments {
    param(
        [string]$SubId,
        [string]$Scope
    )
    
    Write-Evidence "Collecting RBAC role assignments for scope: $Scope"
    
    try {
        $assignments = az role assignment list `
            --subscription $SubId `
            --scope $Scope `
            --output json 2>$null | ConvertFrom-Json
        
        Write-Evidence "Found $($assignments.Count) role assignment(s)"
        return $assignments
    }
    catch {
        Write-EvidenceError "Failed to list role assignments: $_"
        return @()
    }
}

# ============================================================================
# Main Execution
# ============================================================================

function Main {
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  Azure FinOps Inventory Collection Script" -ForegroundColor Cyan
    Write-Host "  Version: 1.0.0" -ForegroundColor Cyan
    Write-Host "  Date: 2026-02-17 08:20 AM ET" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Pre-flight checks
    if (-not (Test-AzureCLI)) {
        Write-EvidenceError "Azure CLI validation failed. Exiting."
        exit 1
    }
    
    $account = Get-CurrentAzureAccount
    if (-not $account) {
        Write-EvidenceError "Azure account validation failed. Run 'az login' and retry."
        exit 1
    }
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        Write-Evidence "Created output directory: $OutputDirectory"
    }
    
    # Generate timestamp for file names
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    
    # Collect inventory for each subscription
    foreach ($subId in $SubscriptionIds) {
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Yellow
        Write-Host "  Processing Subscription: $subId" -ForegroundColor Yellow
        Write-Host "================================================================" -ForegroundColor Yellow
        Write-Host ""
        
        # Set active subscription
        az account set --subscription $subId 2>$null
        
        # 1. Storage Accounts
        $storageAccounts = Get-StorageAccountInventory -SubId $subId
        Save-JsonOutput `
            -FilePath "$OutputDirectory/storage-accounts-$timestamp.json" `
            -Data $storageAccounts `
            -Description "Storage Accounts"
        
        # 1a. Storage Containers (for FinOps Hub storage)
        $finopsStorage = $storageAccounts | Where-Object { $_.name -eq "marcosandboxfinopshub" }
        if ($finopsStorage) {
            $containers = Get-StorageContainerInventory -AccountName $finopsStorage.name
            Save-JsonOutput `
                -FilePath "$OutputDirectory/storage-containers-$timestamp.json" `
                -Data $containers `
                -Description "Storage Containers (marcosandboxfinopshub)"
        }
        
        # 2. Event Grid System Topics
        $eventTopics = Get-EventGridInventory -SubId $subId
        Save-JsonOutput `
            -FilePath "$OutputDirectory/eventgrid-system-topics-$timestamp.json" `
            -Data $eventTopics `
            -Description "Event Grid System Topics"
        
        # 2a. Event Subscriptions
        $firstTopic = $eventTopics | Select-Object -First 1
        if ($firstTopic) {
            $eventSubs = Get-EventSubscriptions -SubId $subId -TopicName $firstTopic.name
            Save-JsonOutput `
                -FilePath "$OutputDirectory/eventgrid-subscriptions-$timestamp.json" `
                -Data $eventSubs `
                -Description "Event Grid Subscriptions"
        }
        
        # 3. Azure Data Factory
        $adfFactories = Get-DataFactoryInventory -SubId $subId
        Save-JsonOutput `
            -FilePath "$OutputDirectory/adf-factories-$timestamp.json" `
            -Data $adfFactories `
            -Description "ADF Factories"
        
        # 3a. ADF Pipelines
        $firstFactory = $adfFactories | Select-Object -First 1
        if ($firstFactory) {
            $adfPipelines = Get-ADFPipelines -SubId $subId -FactoryName $firstFactory.name
            Save-JsonOutput `
                -FilePath "$OutputDirectory/adf-pipelines-$timestamp.json" `
                -Data $adfPipelines `
                -Description "ADF Pipelines"
            
            # 3b. ADF Triggers
            $adfTriggers = Get-ADFTriggers -SubId $subId -FactoryName $firstFactory.name
            Save-JsonOutput `
                -FilePath "$OutputDirectory/adf-triggers-$timestamp.json" `
                -Data $adfTriggers `
                -Description "ADF Triggers"
        }
        
        # 4. Azure Data Explorer (ADX)
        if (-not $SkipADX) {
            $adxClusters = Get-ADXInventory -SubId $subId
            Save-JsonOutput `
                -FilePath "$OutputDirectory/adx-clusters-$timestamp.json" `
                -Data $adxClusters `
                -Description "ADX Clusters"
            
            # 4a. ADX Databases
            $firstCluster = $adxClusters | Select-Object -First 1
            if ($firstCluster) {
                $adxDatabases = Get-ADXDatabases -SubId $subId -ClusterName $firstCluster.name
                Save-JsonOutput `
                    -FilePath "$OutputDirectory/adx-databases-$timestamp.json" `
                    -Data $adxDatabases `
                    -Description "ADX Databases"
            }
        }
        
        # 5. API Management (APIM)
        $apimInstances = Get-APIMInventory -SubId $subId
        Save-JsonOutput `
            -FilePath "$OutputDirectory/apim-instances-$timestamp.json" `
            -Data $apimInstances `
            -Description "APIM Instances"
        
        # 5a. APIM APIs
        $firstApim = $apimInstances | Select-Object -First 1
        if ($firstApim) {
            $apimApis = Get-APIMApis -SubId $subId -ServiceName $firstApim.name
            Save-JsonOutput `
                -FilePath "$OutputDirectory/apim-apis-$timestamp.json" `
                -Data $apimApis `
                -Description "APIM APIs"
            
            # 5b. APIM Loggers
            $apimLoggers = Get-APIMLoggers -SubId $subId -ServiceName $firstApim.name
            Save-JsonOutput `
                -FilePath "$OutputDirectory/apim-loggers-$timestamp.json" `
                -Data $apimLoggers `
                -Description "APIM Loggers"
        }
        
        # 6. Cost Management Exports
        $costExports = Get-CostExports -SubId $subId
        Save-JsonOutput `
            -FilePath "$OutputDirectory/cost-exports-$subId-$timestamp.json" `
            -Data $costExports `
            -Description "Cost Exports"
        
        # 7. Application Insights
        $appInsights = Get-AppInsights -SubId $subId
        Save-JsonOutput `
            -FilePath "$OutputDirectory/appinsights-$timestamp.json" `
            -Data $appInsights `
            -Description "App Insights"
        
        # 8. RBAC Assignments (storage scope)
        if ($finopsStorage) {
            $storageScope = $finopsStorage.id
            $storageRbac = Get-RBACAssignments -SubId $subId -Scope $storageScope
            Save-JsonOutput `
                -FilePath "$OutputDirectory/storage-rbac-$timestamp.json" `
                -Data $storageRbac `
                -Description "Storage RBAC Assignments"
        }
    }
    
    # Summary
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "  Inventory Collection Complete" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Evidence "Output directory: $OutputDirectory" -Color Green
    Write-Evidence "Timestamp: $timestamp" -Color Green
    
    $fileCount = (Get-ChildItem -Path $OutputDirectory -Filter "*-$timestamp.json").Count
    Write-Evidence "Files generated: $fileCount" -Color Green
    
    Write-Host ""
    Write-Evidence "Next Steps:" -Color Cyan
    Write-Host "  1. Review JSON files in $OutputDirectory"
    Write-Host "  2. Compare with previous baseline (if exists)"
    Write-Host "  3. Update docs/finops/00-current-state-inventory.md with findings"
    Write-Host "  4. Generate screenshots for missing manual evidence"
    Write-Host ""
}

# Execute main function
Main