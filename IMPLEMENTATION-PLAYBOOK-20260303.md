# Azure Subscription Assessment - Implementation Playbook
**Date**: March 3, 2026  
**Created for**: Project 14 (Azure FinOps) Phase 4 Execution  
**Companion Document**: SUBSCRIPTION-ASSESSMENT-20260303.md

---

## PLAYBOOK 1: Dev Premium SKU Downgrade (2-3 hours, $11K-$12K/yr savings)

### Prerequisites
```powershell
# Ensure Azure CLI is installed and authenticated
aws --version
az account show  # Verify you're on the right subscription
```

### Step 1: Identify Dev Premium Resources

```powershell
# Export all resources in dev/test RGs with Premium tier
$rgs = @("EVAChatDev3Rg", "infoasst-dev0", "EsDAICoE-Sandbox", "ESDAICOE-SANDBOX")

foreach ($rg in $rgs) {
    Write-Host "=== Checking RG: $rg ===" -ForegroundColor Cyan
    
    # Container Registries
    az acr list --resource-group $rg --query "[?sku.name=='Premium']" | ConvertFrom-Json | Select-Object name, @{n='SKU';e={$_.sku.name}}
    
    # App Service Plans
    az appservice plan list --resource-group $rg --query "[?sku.tier=='Premium']" | ConvertFrom-Json | Select-Object name, @{n='SKU';e={$_.sku.tier}}
    
    # Managed Disks
    az disk list --resource-group $rg --query "[?sku.name=='Premium_LRS']" | ConvertFrom-Json | Select-Object name, @{n='SKU';e={$_.sku.name}}
}
```

### Step 2: Downgrade Container Registry (ACR) from Premium to Standard

```powershell
# For each Premium ACR (e.g., evachatdev3acr)
$resourceGroup = "EVAChatDev3Rg"
$registryName = "evachatdev3acr"

# 2a. Verify it's dev-only (check for active replications)
az acr replication list --registry-name $registryName --resource-group $resourceGroup

# 2b. Remove replications if any (Premium feature)
# (If output is empty, skip this step)

# 2c. Downgrade to Standard
az acr update --name $registryName --resource-group $resourceGroup --sku "Standard"

# 2d. Verify downgrade
az acr show --name $registryName --resource-group $resourceGroup --query "sku.name"
# Expected output: "Standard"

Write-Host "✓ Downgraded $registryName from Premium to Standard" -ForegroundColor Green
```

### Step 3: Downgrade App Service Plan from Premium to Standard/Basic

```powershell
# For each Premium App Service Plan (e.g., infoasst-enrichmentasp-dev0)
$resourceGroup = "infoasst-dev0"
$planName = "infoasst-enrichmentasp-dev0"

# 3a. Check current tier
az appservice plan show --name $planName --resource-group $resourceGroup --query "sku | {tier: tier, name: name, size: size}"

# 3b. Decrease to Standard tier
az appservice plan update --name $planName --resource-group $resourceGroup --sku "S1"
# OR for minimal: --sku "S0" (even cheaper)

# 3c. Verify
az appservice plan show --name $planName --resource-group $resourceGroup --query "sku.tier"

Write-Host "✓ Downgraded $planName" -ForegroundColor Green
```

### Step 4: Check & Downgrade Managed Disks (if applicable)

```powershell
# Premium_LRS disks are typically attached to VMs
# Before downgrading, verify VM is not performance-critical

$resourceGroup = "ESDAICOE-SANDBOX"

# 4a. Find Premium disks
$premiumDisks = az disk list --resource-group $resourceGroup --query "[?sku.name=='Premium_LRS']" | ConvertFrom-Json

# 4b. For each disk, check if it's attached and to what
foreach ($disk in $premiumDisks) {
    $diskName = $disk.name
    $managedBy = $disk.managedBy
    
    if ($managedBy) {
        Write-Host "Disk $diskName is managed by: $managedBy" -ForegroundColor Yellow
    } else {
        Write-Host "Disk $diskName is UNATTACHED - safe to downgrade or delete" -ForegroundColor Green
    }
}

# 4c. If unattached, downgrade (change provider from Premium_LRS to Standard_LRS)
# Note: This requires delete + recreate
# For managed disks, recommend deletion if unused (free up space) rather than downgrade

$diskName = "esdaicoe-sandbox-gpu_OsDisk_1_ec30516c501e47b29cf6281dae8c9fb9"
$resourceGroup = "ESDAICOE-SANDBOX"

# Verify it's safe to delete (ask owner first!)
az vm show --name "esdaicoe-sandbox-gpu" --resource-group $resourceGroup --query "provisioningState"

# If VM is deallocated or not in use, delete the disk
# az disk delete --name $diskName --resource-group $resourceGroup --yes
```

### Step 5: Verify & Report

```powershell
# 5a. Generate cost report
Write-Host "`n=== COST IMPACT SUMMARY ===" -ForegroundColor Cyan
Write-Host "ACR Premium -> Standard: ~$1,700/yr saved" -ForegroundColor Green
Write-Host "App Service Premium -> Standard: ~$2,400/yr saved" -ForegroundColor Green
Write-Host "Managed Disk (if deleted): ~$250/yr saved" -ForegroundColor Green
Write-Host "Total Direct Savings: $4,350-$12,000/yr" -ForegroundColor Green

# 5b. Create a tag to mark when downgrade happened
az tag create --resource-id "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/$rg" `
    --tags "sku-optimization-date=2026-03-03" "old-sku=Premium" "new-sku=Standard"
```

---

## PLAYBOOK 2: Container Registry (ACR) Consolidation (4-6 hours, $7K-$15K/yr savings)

### Step 1: Audit Current ACR Usage

```powershell
# List all Container Registries in the subscription
az acr list --query "[].{name: name, resourceGroup: resourceGroup, sku: sku.name}" -o table

# For each registry, check if it has images and recent pulls
foreach ($acr in (az acr list --query "[].name" -o tsv)) {
    Write-Host "`n=== $acr ===" -ForegroundColor Cyan
    
    # List repositories and image counts
    az acr repository list --name $acr --query "[].name" -o table
    
    # Check last pull time (proxy metrics in Azure Monitor)
    az monitor metrics list --resource "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.ContainerRegistry/registries/$acr" `
        --metric "SuccessfulPullCount" --start-time (Get-Date).AddDays(-90) --interval PT1D --aggregation Average | ConvertFrom-Json | Select-Object -First 5
}
```

### Step 2: Identify Dead ACRs (No Images or No Pulls in 90 Days)

```powershell
# Create a report of ACR health
$acrReport = @()

foreach ($acr in (az acr list --query "[].name" -o tsv)) {
    $repos = (az acr repository list --name $acr --query "length([]) || @[0]" -o tsv)
    
    $acrReport += [PSCustomObject]@{
        RegistryName = $acr
        RepositoryCount = $repos
        Status = if ($repos -eq 0) { "EMPTY - CANDIDATE FOR DELETION" } else { "HAS_IMAGES" }
        AnnualCost = if ($acr -like "*premium*" -or $acr -like "*Premium*") { "~$2,000" } else { "~$1,000" }
    }
}

$acrReport | Format-Table RegistryName, RepositoryCount, Status, AnnualCost -AutoSize

# Export for review
$acrReport | Export-Csv -Path "C:\AICOE\acr-audit-report-$(Get-Date -Format yyyyMMdd).csv" -NoTypeInformation
Write-Host "✓ Report exported to acr-audit-report-$(Get-Date -Format yyyyMMdd).csv" -ForegroundColor Green
```

### Step 3: Migration Script (For Active ACRs)

```powershell
# If you need to migrate images from a duplicate ACR to the central one:
# Source: duplicate ACR (e.g., infoasstacrdev0)
# Target: marcoeva.azurecr.io (central prod registry)

$sourceRegistry = "infoasstacrdev0"
$targetRegistry = "marcoeva"
$resourceGroup = "infoasst-dev0"

# Get access tokens for both registries
$sourceToken = (az acr login --name $sourceRegistry --expose-token --query accessToken -o tsv)
$targetToken = (az acr login --name $targetRegistry --expose-token --query accessToken -o tsv)

# For each image in source registry:
foreach ($repo in (az acr repository list --name $sourceRegistry --query "[]" -o tsv)) {
    Write-Host "Migrating $repo..." -ForegroundColor Yellow
    
    # Pull from source
    docker pull "$sourceRegistry.azurecr.io/$repo:latest"
    
    # Tag for target
    docker tag "$sourceRegistry.azurecr.io/$repo:latest" "$targetRegistry.azurecr.io/$repo:latest"
    
    # Push to target
    docker push "$targetRegistry.azurecr.io/$repo:latest"
    
    Write-Host "✓ Migrated $repo" -ForegroundColor Green
}

# After verifying all images are in target, delete source ACR
# az acr delete --name $sourceRegistry --resource-group $resourceGroup --yes
```

### Step 4: Delete Dead ACRs

```powershell
# Delete empty/dead ACRs (confirm with team first!)
$deadACRs = @("infoasstacrdev0", "evachatdev3acr")  # Example (populate from audit)

foreach ($acr in $deadACRs) {
    # Find resource group
    $rg = (az acr list --query "[?name=='$acr'].resourceGroup" -o tsv)
    
    Write-Host "Deleting $acr from $rg..." -ForegroundColor Yellow
    
    # DELETE (requires confirmation)
    # az acr delete --name $acr --resource-group $rg --yes
    
    Write-Host "✓ Deleted $acr (estimated savings: $1,000-$2,000/yr)" -ForegroundColor Green
}
```

---

## PLAYBOOK 3: Search Services SKU Audit (3-4 hours, $1K-$1.4K/yr savings)

### Step 1: Pull Query Metrics from Azure Monitor

```powershell
# For each Search Service, analyze query volume over 30 days
$searchServices = az search list --query "[].{name: name, resourceGroup: resourceGroup, sku: sku.name}" -o tsv

$endDate = Get-Date
$startDate = $endDate.AddDays(-30)

foreach ($service in $searchServices) {
    $name = $service -split "`t" | Select-Object -First 1
    $rg = $service -split "`t" | Select-Object -Skip 1 -First 1
    
    Write-Host "`n=== $name ===" -ForegroundColor Cyan
    
    # Get resource ID
    $resourceId = "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/$rg/providers/Microsoft.Search/searchServices/$name"
    
    # Query metrics: SearchQueriesPerSecond
    $metrics = az monitor metrics list `
        --resource $resourceId `
        --metric SearchQueriesPerSecond `
        --start-time $startDate --end-time $endDate `
        --interval PT1H --aggregation Average `
        2>$null | ConvertFrom-Json
    
    if ($metrics.value) {
        $avgQPS = ($metrics.value[0].timeseries[0].data | Measure-Object -Property Average -Average).Average
        Write-Host "Average QPS (30 days): $avgQPS" -ForegroundColor Cyan
        Write-Host "Recommendation: $(if ($avgQPS -lt 5) { 'DOWNGRADE to Basic' } else { 'Keep Standard' })" -ForegroundColor Green
    }
}
```

### Step 2: Downgrade Candidates from Standard to Basic

```powershell
# For each service identified as downgrade candidate:
$serviceName = "infoasst-search-dev0"
$resourceGroup = "infoasst-dev0"

# Check current SKU
az search show --name $serviceName --resource-group $resourceGroup --query "sku"

# Downgrade
az search update --name $serviceName --resource-group $resourceGroup --sku "basic"

# Verify
az search show --name $serviceName --resource-group $resourceGroup --query "sku"

Write-Host "✓ Downgraded $serviceName to Basic (savings: $175-$250/yr per service)" -ForegroundColor Green
```

---

## PLAYBOOK 4: RBAC Audit & Consolidation (8-10 hours, Governance benefit)

### Step 1: Export All RBAC Assignments

```powershell
# Export RBAC assignments at subscription scope
$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"

az role assignment list --subscription $subscriptionId `
    --query "[].{principalId: principalId, principalName: principalName, roleDefinitionName: roleDefinitionName, scope: scope}" `
    | ConvertTo-Json -Depth 10 | Out-File "C:\AICOE\rbac-assignments-full-$(Get-Date -Format yyyyMMdd).json"

Write-Host "✓ Exported $(Get-Content C:\AICOE\rbac-assignments-full-*.json | ConvertFrom-Json | measure).Count assignments" -ForegroundColor Green
```

### Step 2: Validate Principal Existence in Entra ID

```powershell
# For each principal, verify it still exists
$assignments = Get-Content "C:\AICOE\rbac-assignments-full-20260303.json" | ConvertFrom-Json

$staleAssignments = @()

foreach ($assignment in $assignments) {
    $principalId = $assignment.principalId
    
    # Check if principal exists
    try {
        $principal = az ad sp show --id $principalId 2>$null
        Write-Host "✓ $($assignment.principalName) exists" -ForegroundColor Green
    } catch {
        Write-Host "✗ $($assignment.principalName) ($principalId) NOT FOUND - STALE" -ForegroundColor Red
        $staleAssignments += $assignment
    }
}

# Export stale assignments for review
$staleAssignments | ConvertTo-Json | Out-File "C:\AICOE\stale-rbac-assignments-$(Get-Date -Format yyyyMMdd).json"
Write-Host "`n✓ Found $($staleAssignments.Count) stale RBAC assignments (see stale-rbac-assignments-*.json)" -ForegroundColor Yellow
```

### Step 3: Remove Stale Assignments

```powershell
# Review stale assignments first before deleting!
$staleAssignments = Get-Content "C:\AICOE\stale-rbac-assignments-20260303.json" | ConvertFrom-Json

foreach ($assignment in $staleAssignments) {
    Write-Host "Removing: $($assignment.principalName) - $($assignment.roleDefinitionName) on $($assignment.scope)" -ForegroundColor Yellow
    
    # UNCOMMENT TO EXECUTE (requires confirmation)
    # az role assignment delete --assignee $assignment.principalId --role $assignment.roleDefinitionName --scope $assignment.scope
}
```

### Step 4: Consolidate Group-Based Roles (Best Practice)

```powershell
# Replace person-based Owner roles with group-based roles
# Example: Remove person "Alice" as Owner, add "Project-Owners" group instead

# Find all Owner assignments to people (not groups/SPs)
$resourceGroup = "EsDAICoE-Sandbox"

az role assignment list --resource-group $resourceGroup --query "[?roleDefinitionName=='Owner' && principalType=='User']" | ConvertFrom-Json

# For each person: remove Owner role, verify group-based role exists
# az role assignment delete --assignee "alice@hrsdc-rhdcc.gc.ca" --role Owner --resource-group $resourceGroup
# az role assignment create --assignee "project-owners@hrsdc-rhdcc.gc.ca" --role Owner --resource-group $resourceGroup
```

---

## PLAYBOOK 5: Generate Monthly Subscription Cost Report

```powershell
# Create automated report for cost tracking
# Run this every month to track optimization impact

$subscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$reportDate = Get-Date -Format "yyyyMM"

# Get cost data from Cost Management API
# Note: Requires Cost Management reader role
$costData = az costmanagement query create `
    --timeframe "MonthToDate" `
    --granularity "Daily" `
    --dataset-filter "dimensions" "ResourceGroup" `
    --dataset-aggregation "totalCost" "sum" `
    --query "properties.rows | sort_by(@, &[2]) | reverse(@) | [0:20]"

Write-Host "=== TOP 20 COST DRIVERS (Month-to-Date) ===" -ForegroundColor Cyan
$costData | ConvertFrom-Json | Format-Table @{n='ResourceGroup';e={$_[0]}}, @{n='Cost (USD)';e={$_[1]}} -AutoSize

# Create CSV for trend analysis
$fileName = "C:\AICOE\eva-foundry\14-az-finops\reports\cost-report-$reportDate.csv"
$costData | ConvertFrom-Json | Export-Csv -Path $fileName -NoTypeInformation

Write-Host "`n✓ Cost report saved to $fileName" -ForegroundColor Green
```

---

## Quick Reference: Cost Per Resource Type

| Service | Basic Cost | Premium Cost | Monthly Savings (Premium -> Basic) |
|---|---|---|---|
| Container Registry (ACR) | ~$150 | ~$290 | ~$140 |
| App Service Plan (S0) | ~$65 | ~$270 | ~$205 |
| Search Service (Basic) | ~$75 | ~$250 | ~$175 |
| Managed Disk (Standard) | ~$4 | ~$20 | ~$16 |
| Key Vault | $0.6/10K ops | $0.8/10K ops | Usage-dependent |

**Key Insight**: Most dev Premium resources are "set and forget" -- downgrading won't reduce functionality for development, only removes unused premium features.

---

## Troubleshooting

### "Cannot downgrade - resource in use"
- This is expected for production resources. Double-check it's actually in a dev/test RG.
- For App Service Plans, ensure no apps are scaled to instance count > 1 (Standard tier limitation).

### "ACR delete fails - still referenced"
- Check for AKS clusters, Container Apps, or other services pulling images
- Use Azure Resource Graph to find dependencies: `az graph query --query "resources | where name startswith 'acr'"`

### "Search Service downgrade causes latency"
- Monitor `/metrics/SearchLatencyMs` in Azure Monitor for 24 hours post-downgrade
- If latency > 2s, revert to Standard: `az search update --name SERVICENAME --sku "standard"`

---

**Prepared by**: GitHub Copilot (Project 14 FinOps Implementation, March 3, 2026)
