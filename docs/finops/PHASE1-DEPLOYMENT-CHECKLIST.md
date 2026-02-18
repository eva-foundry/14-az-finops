# Phase 1 Deployment Checklist - FinOps Hub Foundation

**Document Type**: Operational  
**Phase**: Implementation - Phase 1 (Weeks 1-2)  
**Audience**: [devops-engineers, cloud-architects]  
**Date**: 2026-02-17 08:20 AM ET  
**Author**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Status**: Ready for Execution

---

## Phase 1 Overview

**Goal**: Establish storage infrastructure, event routing, and validation framework for FinOps Hub data ingestion.

**Duration**: 2 weeks (Sprint 1-2)  
**Story Points**: 13 points  
**Prerequisites**: Azure CLI authenticated, Contributor access on EsDAICoE-Sandbox RG  
**Dependencies**: None (foundational phase)

**Deliverables**:
1. ✅ Structured storage containers (raw, processed, archive, checkpoint)
2. ✅ Lifecycle management policy (90-day Cool tier, 180-day Archive tier)
3. ✅ Cost export migration to new hierarchy
4. ✅ Event Grid subscription to ADF webhook
5. ✅ Pre-deployment baseline captured (completed 2026-02-17 09:09 AM ET)

---

## Pre-Deployment Checklist

### Environment Preparation

- [x] **Baseline Inventory Captured**: 2026-02-17 09:09:32 AM ET
  - Location: `i:\eva-foundation\14-az-finops\tools\finops\out\`
  - Files: 12 JSON artifacts (storage, APIM, Event Grid, RBAC)
  
- [ ] **Azure CLI Authentication**
  ```powershell
  # Verify authentication
  az account show --query "{User: user.name, Subscription: name}" --output table
  
  # Expected: marco.presta@hrsdc-rhdcc.gc.ca, EsDAICoESub
  # If not: az login --use-device-code --tenant bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8
  ```

- [ ] **Set Target Subscription**
  ```powershell
  az account set --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba
  az account show --query name
  # Expected output: EsDAICoESub
  ```

- [ ] **Verify Permissions**
  ```powershell
  az role assignment list \
    --assignee marco.presta@hrsdc-rhdcc.gc.ca \
    --resource-group EsDAICoE-Sandbox \
    --query "[?roleDefinitionName=='Contributor' || roleDefinitionName=='Owner']"
  
  # Required: Contributor or Owner on EsDAICoE-Sandbox RG
  ```

- [ ] **Review Deployment Plan**
  - Read: `i:\eva-foundation\14-az-finops\docs\finops\03-deployment-plan.md` → Phase 1
  - Understand: Bicep modules, acceptance criteria, rollback procedures

---

## Task 1.1.1: Create Storage Containers (XS - 1 point)

**Objective**: Create 4 containers in `marcosandboxfinopshub` for structured cost data storage.

### Implementation Steps

1. **Navigate to Project Directory**
   ```powershell
   cd i:\eva-foundation\14-az-finops\infra
   ```

2. **Create Storage Containers**
   ```powershell
   # Set variables
   $storageAccount = "marcosandboxfinopshub"
   $resourceGroup = "EsDAICoE-Sandbox"
   
   # Create containers
   $containers = @("raw", "processed", "archive", "checkpoint")
   
   foreach ($container in $containers) {
       Write-Host "[INFO] Creating container: $container" -ForegroundColor Cyan
       az storage container create `
         --account-name $storageAccount `
         --name $container `
         --auth-mode login `
         --public-access off
   }
   ```

3. **Verify Container Creation**
   ```powershell
   # List all containers
   az storage container list `
     --account-name $storageAccount `
     --auth-mode login `
     --query "[].name" --output table
   
   # Expected: config, costs, ingestion, raw, processed, archive, checkpoint (7+ containers)
   ```

4. **Test File Upload**
   ```powershell
   # Create test file
   "Test content for FinOps Hub - Phase 1 validation" | Out-File -FilePath "test-upload.txt"
   
   # Upload to each new container
   foreach ($container in @("raw", "processed", "archive", "checkpoint")) {
       az storage blob upload `
         --account-name $storageAccount `
         --container-name $container `
         --name "test-phase1.txt" `
         --file "test-upload.txt" `
         --auth-mode login
       
       Write-Host "[PASS] Upload succeeded for $container" -ForegroundColor Green
   }
   
   # Cleanup test file
   Remove-Item "test-upload.txt"
   ```

### Acceptance Criteria

- [ ] All 4 containers visible via `az storage container list`
- [ ] Container access level: Private (no anonymous access)
- [ ] Test file upload succeeds in each container
- [ ] Screenshot saved: Portal → Storage Account → Containers blade → `phase1-containers-created.png`

### Evidence Artifacts

```powershell
# Save container inventory
az storage container list `
  --account-name marcosandboxfinopshub `
  --auth-mode login `
  --output json | Out-File -FilePath "i:\eva-foundation\14-az-finops\tools\finops\out\containers-after-phase1-task1.json"
```

---

## Task 1.1.2: Configure Lifecycle Management Policy (S - 2 points)

**Objective**: Implement auto-tiering to Cool (90 days) and Archive (180 days) for cost optimization.

### Implementation Steps

1. **Create Bicep Module** (already provided in 03-deployment-plan.md)
   
   Create file: `i:\eva-foundation\14-az-finops\infra\bicep\storage-lifecycle.bicep`
   ```bicep
   param storageAccountName string = 'marcosandboxfinopshub'
   param location string = 'canadacentral'
   
   resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
     name: storageAccountName
   }
   
   resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
     name: 'default'
     parent: storageAccount
     properties: {
       policy: {
         rules: [
           {
             enabled: true
             name: 'MoveRawToCool'
             type: 'Lifecycle'
             definition: {
               actions: {
                 baseBlob: {
                   tierToCool: {
                     daysAfterModificationGreaterThan: 90
                   }
                   tierToArchive: {
                     daysAfterModificationGreaterThan: 180
                   }
                 }
               }
               filters: {
                 blobTypes: [ 'blockBlob' ]
                 prefixMatch: [ 'raw/' ]
               }
             }
           }
           {
             enabled: true
             name: 'MoveProcessedToArchive'
             type: 'Lifecycle'
             definition: {
               actions: {
                 baseBlob: {
                   tierToArchive: {
                     daysAfterModificationGreaterThan: 180
                   }
                 }
               }
               filters: {
                 blobTypes: [ 'blockBlob' ]
                 prefixMatch: [ 'processed/' ]
               }
             }
           }
         ]
       }
     }
   }
   ```

2. **Deploy Bicep Module**
   ```powershell
   cd i:\eva-foundation\14-az-finops\infra\bicep
   
   az deployment group create `
     --resource-group EsDAICoE-Sandbox `
     --template-file storage-lifecycle.bicep `
     --parameters storageAccountName=marcosandboxfinopshub location=canadacentral
   ```

3. **Verify Deployment**
   ```powershell
   # Check lifecycle policy
   az storage account management-policy show `
     --account-name marcosandboxfinopshub `
     --resource-group EsDAICoE-Sandbox `
     --output json
   ```

4. **Validate in Portal**
   - Navigate to: Portal → marcosandboxfinopshub → Lifecycle management
   - Verify: 2 rules visible (MoveRawToCool, MoveProcessedToArchive)
   - Screenshot: Save as `phase1-lifecycle-policy.png`

### Acceptance Criteria

- [ ] Bicep module deploys successfully (no errors)
- [ ] Policy visible in Portal → Storage Account → Lifecycle management
- [ ] Rule count: 2 (MoveRawToCool, MoveProcessedToArchive)
- [ ] Rule details match expected tiers (90 days Cool, 180 days Archive)
- [ ] Evidence saved: `az storage account management-policy show` output

### Rollback Procedure

```powershell
# If policy causes issues, delete it
az storage account management-policy delete `
  --account-name marcosandboxfinopshub `
  --resource-group EsDAICoE-Sandbox
```

---

## Task 1.1.3: Migrate Existing Exports to Raw Container (M - 3 points)

**Objective**: Reorganize current `costs/` blobs into hierarchical `raw/costs/{subscription}/{YYYY}/{MM}/` structure.

### Implementation Steps

1. **Analyze Current Blob Structure**
   ```powershell
   # List current costs container structure
   az storage blob list `
     --container-name costs `
     --account-name marcosandboxfinopshub `
     --auth-mode login `
     --query "[].{Name:name, Size:properties.contentLength, Modified:properties.lastModified}" `
     --output table | Out-File -FilePath "costs-container-before-migration.txt"
   
   # Count blobs
   $blobCount = (az storage blob list --container-name costs --account-name marcosandboxfinopshub --auth-mode login --query "length(@)")
   Write-Host "[INFO] Total blobs to migrate: $blobCount"
   ```

2. **Create Migration Script**
   
   Create file: `i:\eva-foundation\14-az-finops\scripts\migrate-costs-to-raw.ps1`
   ```powershell
   #Requires -Version 5.1
   <#
   .SYNOPSIS
       Migrate cost export blobs from costs/ to raw/costs/ with hierarchy
   #>
   
   param(
       [string]$StorageAccount = "marcosandboxfinopshub",
       [string]$SourceContainer = "costs",
       [string]$DestinationContainer = "raw",
       [switch]$DryRun
   )
   
   Write-Host "================================================================" -ForegroundColor Cyan
   Write-Host "  Cost Export Migration Script" -ForegroundColor Cyan
   Write-Host "  Source: $SourceContainer" -ForegroundColor Cyan
   Write-Host "  Destination: $DestinationContainer/costs/" -ForegroundColor Cyan
   Write-Host "================================================================" -ForegroundColor Cyan
   
   # Get all blobs from source container
   $blobs = az storage blob list `
     --container-name $SourceContainer `
     --account-name $StorageAccount `
     --auth-mode login `
     --output json | ConvertFrom-Json
   
   Write-Host "[INFO] Found $($blobs.Count) blobs to migrate"
   
   $migratedCount = 0
   $skippedCount = 0
   $errorCount = 0
   
   foreach ($blob in $blobs) {
       $sourceName = $blob.name
       
       # Parse subscription and date from blob name
       # Expected pattern: EsDAICoESub_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/ActualCost/YYYYMMDD-YYYYMMDD/exports_export-name_xxxxxxxx-xxxx-xxxx.csv.gz
       if ($sourceName -match '^([^_]+)_([^/]+)/.*?/(\d{4})(\d{2})\d{2}-\d{8}/') {
           $subscriptionName = $Matches[1]
           $year = $Matches[3]
           $month = $Matches[4]
           
           $destinationName = "$DestinationContainer/costs/$subscriptionName/$year/$month/$sourceName"
           
           if ($DryRun) {
               Write-Host "[DRY-RUN] Would copy: $sourceName -> $destinationName" -ForegroundColor Yellow
               $migratedCount++
           } else {
               try {
                   # Copy blob (preserves original)
                   az storage blob copy start `
                     --account-name $StorageAccount `
                     --destination-blob $destinationName `
                     --destination-container $DestinationContainer `
                     --source-container $SourceContainer `
                     --source-blob $sourceName `
                     --auth-mode login | Out-Null
                   
                   Write-Host "[PASS] Copied: $sourceName" -ForegroundColor Green
                   $migratedCount++
               } catch {
                   Write-Host "[ERROR] Failed to copy $sourceName : $_" -ForegroundColor Red
                   $errorCount++
               }
           }
       } else {
           Write-Host "[WARN] Skipping blob (unrecognized pattern): $sourceName" -ForegroundColor Yellow
           $skippedCount++
       }
   }
   
   Write-Host "`n================================================================" -ForegroundColor Cyan
   Write-Host "  Migration Summary" -ForegroundColor Cyan
   Write-Host "================================================================" -ForegroundColor Cyan
   Write-Host "  Migrated: $migratedCount" -ForegroundColor Green
   Write-Host "  Skipped:  $skippedCount" -ForegroundColor Yellow
   Write-Host "  Errors:   $errorCount" -ForegroundColor Red
   Write-Host "================================================================" -ForegroundColor Cyan
   ```

3. **Execute Migration (Dry Run First)**
   ```powershell
   cd i:\eva-foundation\14-az-finops\scripts
   
   # Dry run to validate logic
   .\migrate-costs-to-raw.ps1 -DryRun
   
   # Review output, then execute for real
   .\migrate-costs-to-raw.ps1
   ```

4. **Validation**
   ```powershell
   # Check raw container structure
   az storage blob list `
     --container-name raw `
     --account-name marcosandboxfinopshub `
     --auth-mode login `
     --prefix "costs/" `
     --query "[].name" `
     --output table | Out-File -FilePath "raw-container-after-migration.txt"
   
   # Compare blob counts
   $sourceCount = (az storage blob list --container-name costs --account-name marcosandboxfinopshub --auth-mode login --query "length(@)")
   $destCount = (az storage blob list --container-name raw --account-name marcosandboxfinopshub --auth-mode login --prefix "costs/" --query "length(@)")
   
   Write-Host "[INFO] Source blobs: $sourceCount"
   Write-Host "[INFO] Destination blobs: $destCount"
   
   if ($sourceCount -eq $destCount) {
       Write-Host "[PASS] Blob count matches" -ForegroundColor Green
   } else {
       Write-Host "[WARN] Blob count mismatch - review migration log" -ForegroundColor Yellow
   }
   ```

5. **Rename Original Container** (retain for safety)
   ```powershell
   # Rename costs container to costs-old (manual in Portal for safety)
   # Do NOT delete original container until Phase 1 validation complete
   ```

### Acceptance Criteria

- [ ] Migration script completes without critical errors
- [ ] Blob count in `raw/costs/` matches original `costs/` container
- [ ] Hierarchical structure validated: `raw/costs/{subscription}/{YYYY}/{MM}/`
- [ ] Spot-check: Download and compare 5 random CSVs (row count match)
- [ ] Original `costs/` container renamed to `costs-old` (not deleted)
- [ ] Migration log saved: `migration-log-YYYYMMDD-HHMMSS.txt`

### Rollback Procedure

```powershell
# If migration issues found, original costs/ container is preserved as costs-old
# Can continue using costs-old until issues resolved
# Delete raw/costs/ prefix and retry migration
```

---

## Task 1.2.1: Update Cost Management Export Destinations (S - 2 points)

**Objective**: Reconfigure portal exports to target `raw/costs/{SubscriptionName}` path.

### Implementation Steps

1. **Portal Configuration** (Manual - Azure CLI not supported for this operation)
   
   **For EsDAICoESub-Daily Export**:
   - Navigate to: Portal → Cost Management → Exports
   - Select: `EsDAICoESub-Daily`
   - Edit → Destination settings
   - Update:
     - Storage account: `marcosandboxfinopshub`
     - Container: `raw`
     - Directory: `costs/EsDAICoESub`
   - Save
   
   **For EsPAICoESub-Daily Export**:
   - Navigate to: Portal → Cost Management → Exports
   - Select: `EsPAICoESub-Daily`
   - Edit → Destination settings
   - Update:
     - Storage account: `marcosandboxfinopshub`
     - Container: `raw`
     - Directory: `costs/EsPAICoESub`
   - Save

2. **Trigger Manual Export** (Test)
   ```powershell
   # Portal: Select export → Run now
   # Wait 2-5 minutes for export to complete
   ```

3. **Verify New Blob Location**
   ```powershell
   # Check for blobs in new location
   az storage blob list `
     --container-name raw `
     --account-name marcosandboxfinopshub `
     --auth-mode login `
     --prefix "costs/EsDAICoESub" `
     --query "[0].name" `
     --output tsv
   
   # Expected: raw/costs/EsDAICoESub/ActualCost/YYYYMMDD-YYYYMMDD/...csv.gz
   ```

### Acceptance Criteria

- [ ] Both exports (EsDAICoESub-Daily, EsPAICoESub-Daily) updated in Portal
- [ ] Manual trigger succeeds for both exports
- [ ] New blobs land in `raw/costs/{SubscriptionName}/` path
- [ ] Export history shows updated root folder path
- [ ] Screenshots saved: Export configuration + successful run history

---

## Task 1.3.1: Verify Event Grid System Topic (S - 2 points)

**Objective**: Confirm existing system topic is active and receiving events.

### Implementation Steps

1. **Verify System Topic Existence**
   ```powershell
   # Get system topic details
   az eventgrid system-topic list `
     --resource-group EsDAICoE-Sandbox `
     --query "[?contains(source,'marcosandboxfinopshub')]" `
     --output table
   
   # Save topic name for next task
   $topicName = (az eventgrid system-topic list --resource-group EsDAICoE-Sandbox --query "[?contains(source,'marcosandboxfinopshub')].name" --output tsv)
   Write-Host "[INFO] System topic name: $topicName"
   ```

2. **Check Provisioning State**
   ```powershell
   az eventgrid system-topic show `
     --name $topicName `
     --resource-group EsDAICoE-Sandbox `
     --query "{Name:name, State:provisioningState, TopicType:topicType}" `
     --output table
   
   # Expected: State = Succeeded
   ```

3. **Verify Metrics** (Portal)
   - Navigate to: Portal → Event Grid System Topic → $topicName → Metrics
   - Chart: Published Events (last 24 hours)
   - Expected: Events visible after next cost export run
   - Screenshot: Save as `phase1-eventgrid-metrics.png`

### Acceptance Criteria

- [ ] System topic status: Succeeded
- [ ] Topic type: `Microsoft.Storage.StorageAccounts`
- [ ] Source: `/subscriptions/.../marcosandboxfinopshub`
- [ ] Metrics show events (or 0 if no exports ran recently)
- [ ] Evidence saved: `az eventgrid system-topic show` output

---

## Task 1.3.2: Create Event Subscription to ADF (M - 3 points)

**Objective**: Wire Event Grid to trigger ADF pipeline on blob creation in `raw/costs/` prefix.

### Implementation Steps

1. **Get ADF Webhook URL** (Manual - requires ADF pipeline creation in Phase 2)
   
   **Note**: This task has a dependency on Phase 2 Task 2.2.4 (ADF pipeline creation). For now, we'll prepare the Event Grid infrastructure.
   
   ```powershell
   # Placeholder for Phase 2
   Write-Host "[INFO] ADF webhook URL will be configured in Phase 2 after pipeline deployment"
   Write-Host "[INFO] Preparing Event Grid subscription configuration..."
   ```

2. **Create Event Subscription** (Execute during Phase 2)
   
   Create file: `i:\eva-foundation\14-az-finops\infra\azure-cli\create-eventgrid-subscription.sh`
   ```bash
   #!/bin/bash
   # Create Event Grid subscription for FinOps ingestion
   
   SUBSCRIPTION_NAME="finops-ingest-trigger"
   SYSTEM_TOPIC_NAME="<topic-name-from-task-1.3.1>"
   RESOURCE_GROUP="EsDAICoE-Sandbox"
   ADF_WEBHOOK_URL="<adf-webhook-url-from-phase2>"
   
   az eventgrid system-topic event-subscription create \
     --name "$SUBSCRIPTION_NAME" \
     --resource-group "$RESOURCE_GROUP" \
     --system-topic-name "$SYSTEM_TOPIC_NAME" \
     --endpoint-type webhook \
     --endpoint "$ADF_WEBHOOK_URL" \
     --included-event-types "Microsoft.Storage.BlobCreated" \
     --subject-begins-with "/blobServices/default/containers/raw/blobs/costs/" \
     --subject-ends-with ".csv.gz"
   
   echo "[INFO] Event subscription created: $SUBSCRIPTION_NAME"
   ```

3. **Validation** (Phase 2)
   ```powershell
   # Test: Upload sample CSV → ADF pipeline triggered within 2 minutes
   # Check Event Grid Metrics: Delivery success rate = 100%
   ```

### Acceptance Criteria (Phase 2)

- [ ] Event subscription created: `finops-ingest-trigger`
- [ ] Filter: Prefix `/raw/costs/`, Suffix `.csv.gz`
- [ ] Test: Upload sample CSV → ADF pipeline triggered within 2 minutes
- [ ] Delivery success rate: 100% (check Event Grid Metrics)
- [ ] Evidence: Event subscription JSON + ADF run history

**Phase 1 Status**: Preparation only (defer to Phase 2)

---

## Phase 1 Completion Checklist

### Technical Validation

- [ ] **Storage**: 4 new containers (raw, processed, archive, checkpoint) created
- [ ] **Lifecycle Policy**: Deployed via Bicep, visible in Portal
- [ ] **Migration**: Blobs copied to `raw/costs/` hierarchy, original preserved
- [ ] **Cost Exports**: Reconfigured to new destination, manual test successful
- [ ] **Event Grid**: System topic verified, metrics accessible

### Evidence Collection

- [ ] **Baseline (Pre)**: Captured 2026-02-17 09:09:32 AM ET
- [ ] **Post-Task Screenshots**: 5 screenshots (containers, lifecycle, migration, exports, Event Grid)
- [ ] **JSON Artifacts**: Updated inventory after Phase 1 tasks
- [ ] **Migration Log**: Blob count comparison, sample validation

### Documentation Updates

- [ ] **Update 00-current-state-inventory.md**: Add Phase 1 completion notes
- [ ] **Update README.md**: Mark Phase 1 as complete
- [ ] **Create Phase 1 Evidence Pack**: Folder with all screenshots + logs

---

## Rollback Plan

If critical issues arise during Phase 1:

1. **Containers**: Can delete newly created containers (no impact to existing data)
2. **Lifecycle Policy**: Can delete policy without affecting blobs
3. **Migration**: Original `costs/` container preserved as `costs-old`
4. **Exports**: Can revert to original destination in Portal

**Critical Data Protection**: Original `costs/` container is NEVER deleted until Phase 1 fully validated.

---

## Next Steps After Phase 1

1. **Phase 2 Planning**: Schedule ADX cluster deployment (Epic 2, 21 story points)
2. **Stakeholder Update**: Present Phase 1 completion evidence
3. **Backlog Refinement**: Review Phase 2 tasks in `04-backlog.md`
4. **Budget Tracking**: Document Phase 1 costs (storage only, no new services)

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-02-17 08:20 AM ET | Marco Presta | Initial Phase 1 deployment checklist |
| 2026-02-17 09:30 AM ET | Marco Presta | Updated with baseline inventory completion |

---

**Phase 1 Status**: ✅ Ready for Execution  
**Estimated Duration**: 2 weeks (10 business days)  
**Next Review**: After Task 1.1.3 (migration) completion
