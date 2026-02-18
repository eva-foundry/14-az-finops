# 05 - Evidence Pack (Validation Commands & Artifacts)

**Document Type**: Operational  
**Phase**: Validation  
**Audience**: [engineers, auditors, operations]  
**Last Updated**: 2026-02-17 08:20 AM ET  
**Author**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)

---

## Overview

This document provides **executable commands** to validate current state and capture evidence artifacts for audit/compliance purposes. All commands output JSON or tables suitable for version control and comparison over time.

**Output Directory**: `i:/eva-foundation/14-az-finops/tools/finops/out/`  
**Execution Context**: Azure CLI authenticated as marco.presta@hrsdc-rhdcc.gc.ca (professional account)  
**Subscriptions**: EsDAICoESub (d2d4e571-e0f2-4f6c-901a-f88f7669bcba), EsPAICoESub (802d84ab-3189-4221-8453-fcc30c8dc8ea)

---

## 1. Storage Account Validation

### 1.1 List Storage Accounts

**Purpose**: Enumerate all storage accounts in sandbox resource group.

```powershell
# Command
az storage account list \
  --resource-group EsDAICoE-Sandbox \
  --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/storage-accounts.json"

# Expected Output: marcosandboxfinopshub with properties
```

**Validation Points**:
- [ ] `marcosandboxfinopshub` present in results
- [ ] `kind`: StorageV2 (ADLS Gen2 capable)
- [ ] `isHnsEnabled`: true (hierarchical namespace enabled)
- [ ] `location`: canadacentral
- [ ] `sku.name`: Standard_LRS or Standard_GRS

**Evidence Artifact**: `storage-accounts.json` (saved to repo)

---

### 1.2 List Storage Containers

**Purpose**: Enumerate all blob containers in FinOps Hub storage.

```powershell
# Command
az storage container list \
  --account-name marcosandboxfinopshub \
  --auth-mode login \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/storage-containers.json"

# Expected Output: Container list with "costs", potentially "raw", "processed", "checkpoint"
```

**Validation Points**:
- [ ] Container `costs` exists (current location of exports)
- [ ] If migrated: Containers `raw`, `processed`, `archive`, `checkpoint` exist
- [ ] Public access level: None (private)
- [ ] Metadata includes creation timestamp

**Evidence Artifact**: `storage-containers.json`

**Screenshot Required**: Portal → Storage Account → Containers blade

---

### 1.3 Sample Blob Listing

**Purpose**: Validate export file naming and structure.

```powershell
# Command (list last 10 blobs in costs container)
az storage blob list \
  --container-name costs \
  --account-name marcosandboxfinopshub \
  --auth-mode login \
  --num-results 10 \
  --output table

# Expected Output: CSV files with pattern {SubscriptionName}_xxxxxxxx-xxxx.../[date].csv.gz
```

**Validation Points**:
- [ ] Blob names follow Cost Management naming convention
- [ ] File extension: `.csv.gz` (compressed)
- [ ] Size: >100 KB for daily exports, >1 MB for full exports
- [ ] Last modified: Recent (within 24 hours for daily exports)

**Evidence**: Copy-paste table output to `storage-sample-blobs.txt`

---

### 1.4 Network Rules (Firewall)

**Purpose**: Verify public access settings.

```powershell
# Command
az storage account show \
  --name marcosandboxfinopshub \
  --resource-group EsDAICoE-Sandbox \
  --query "{publicAccess: publicNetworkAccess, defaultAction: networkRuleSet.defaultAction, bypass: networkRuleSet.bypass}" \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/storage-network.json"

# Expected Output (before hardening): publicAccess=Enabled, defaultAction=Allow
# Expected Output (after hardening): publicAccess=Disabled, defaultAction=Deny
```

**Validation Points**:
- [ ] Current state: Public access enabled (development phase)
- [ ] Target state: Public access disabled, VNet rules configured (production phase)

**Evidence Artifact**: `storage-network.json`

---

## 2. Event Grid Validation

### 2.1 List Event Grid System Topics

**Purpose**: Confirm storage account has system topic for blob events.

```powershell
# Command
az eventgrid system-topic list \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/eventgrid-system-topics.json"

# Expected Output: One system topic with source=marcosandboxfinopshub
```

**Validation Points**:
- [ ] System topic name: `marcosandboxfinopshub-*` (auto-generated)
- [ ] Topic type: Microsoft.Storage.StorageAccounts
- [ ] Provisioning state: Succeeded
- [ ] Source: `/subscriptions/.../resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Storage/storageAccounts/marcosandboxfinopshub`

**Evidence Artifact**: `eventgrid-system-topics.json`

---

### 2.2 List Event Subscriptions

**Purpose**: Enumerate event subscriptions (if any) wired to ADF or other endpoints.

```powershell
# Command
az eventgrid system-topic event-subscription list \
  --resource-group EsDAICoE-Sandbox \
  --system-topic-name <system-topic-name-from-above> \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/eventgrid-subscriptions.json"

# Expected Output (current): Empty array (no subscriptions yet)
# Expected Output (future): Subscription to ADF webhook for ingest-costs-to-adx pipeline
```

**Validation Points**:
- [ ] If empty: No automated ingestion yet (manual validation required)
- [ ] If populated: Endpoint type, filter prefix (`/raw/costs/`), delivery status

**Evidence Artifact**: `eventgrid-subscriptions.json`

**Screenshot Required**: Portal → Event Grid System Topic → Metrics (Event Count last 7 days)

---

## 3. Azure Data Factory Validation

### 3.1 List Data Factories

**Purpose**: Confirm ADF resource exists in sandbox.

```powershell
# Command
az datafactory list \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/adf-factories.json"

# Expected Output: marco-sandbox-finops-adf
```

**Validation Points**:
- [ ] Factory name: `marco-sandbox-finops-adf`
- [ ] Location: canadacentral
- [ ] Identity: SystemAssigned or UserAssigned (for authentication)
- [ ] Provisioning state: Succeeded

**Evidence Artifact**: `adf-factories.json`

---

### 3.2 List Pipelines

**Purpose**: Enumerate configured pipelines (currently unknown).

```powershell
# Command
az datafactory pipeline list \
  --factory-name marco-sandbox-finops-adf \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/adf-pipelines.json"

# Expected Output (current): Empty array OR legacy pipelines
# Expected Output (future): ingest-costs-to-adx, backfill-historical
```

**Validation Points**:
- [ ] If empty: No automation configured (meets UNKNOWN status from doc 00)
- [ ] If populated: Pipeline activity structure, parameters, triggers

**Evidence Artifact**: `adf-pipelines.json`

**Screenshot Required**: Portal → ADF → Author blade showing pipeline list

---

### 3.3 List Triggers

**Purpose**: Check if Event Grid triggers are configured.

```powershell
# Command
az datafactory trigger list \
  --factory-name marco-sandbox-finops-adf \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/adf-triggers.json"

# Expected Output (current): Empty or no Event Grid trigger
# Expected Output (future): Storage Event trigger for /raw/costs/ blob creation
```

**Validation Points**:
- [ ] Trigger type: BlobEventsTrigger
- [ ] Scope: `/subscriptions/.../resourceGroups/.../storageAccounts/marcosandboxfinopshub`
- [ ] Events: Microsoft.Storage.BlobCreated
- [ ] Status: Started

**Evidence Artifact**: `adf-triggers.json`

---

### 3.4 Check Pipeline Run History

**Purpose**: Validate recent execution (if any).

```powershell
# Command (requires pipeline name, skip if empty)
az datafactory pipeline-run query-by-factory \
  --factory-name marco-sandbox-finops-adf \
  --resource-group EsDAICoE-Sandbox \
  --last-updated-after "2026-02-01T00:00:00Z" \
  --last-updated-before "2026-02-17T23:59:59Z" \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/adf-run-history.json"

# Expected Output (current): Empty array (no runs)
# Expected Output (future): Successful run with duration, row count processed
```

**Validation Points**:
- [ ] Run status: Succeeded
- [ ] Duration: <10 minutes for single CSV ingestion
- [ ] Output: Row count, target table name

**Evidence Artifact**: `adf-run-history.json`

---

## 4. Azure Data Explorer (ADX) Validation

### 4.1 List ADX Clusters

**Purpose**: Check if ADX cluster is deployed.

```powershell
# Command
az kusto cluster list \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/adx-clusters.json"

# Expected Output (current): Empty array (NOT deployed yet)
# Expected Output (future): marcofinopsadx, SKU=Dev, state=Running
```

**Validation Points** (post-deployment):
- [ ] Cluster name: `marcofinopsadx`
- [ ] URI: `https://marcofinopsadx.canadacentral.kusto.windows.net`
- [ ] SKU: Dev_No_SLA_Standard_D11_v2, capacity 2
- [ ] State: Running
- [ ] Provisioning state: Succeeded

**Evidence Artifact**: `adx-clusters.json`

**Note**: If empty, this confirms CRITICAL gap from gap analysis (doc 01).

---

### 4.2 List ADX Databases

**Purpose**: Enumerate databases in cluster (post-deployment).

```powershell
# Command (only after cluster deployed)
az kusto database list \
  --cluster-name marcofinopsadx \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/adx-databases.json"

# Expected Output: finopsdb with retention, hot cache settings
```

**Validation Points**:
- [ ] Database name: `finopsdb`
- [ ] Hot cache period: 31 days
- [ ] Soft delete period: 1825 days (5 years)

**Evidence Artifact**: `adx-databases.json`

---

### 4.3 KQL Validation Queries

**Purpose**: Validate ADX schema and sample data (post-ingestion).

**Commands** (execute in ADX Web Explorer: https://dataexplorer.azure.com):

```kql
// 1. List tables
.show tables

// Expected Output: raw_costs, apim_usage

// 2. Check materialized views
.show materialized-views

// Expected Output: normalized_costs

// 3. Check functions
.show functions

// Expected Output: AllocateCostByApp

// 4. Validate ingestion mappings
.show table raw_costs ingestion csv mappings

// Expected Output: CostExportMapping with 55+ column mappings

// 5. Row count validation (after ingestion)
raw_costs
| summarize Count=count() by Date
| order by Date desc
| take 30

// Expected Output: Daily row counts matching subscription activity

// 6. Cost trend validation
normalized_costs
| where Date >= ago(30d)
| summarize DailyCost=sum(Cost) by Date, SubscriptionName
| order by Date desc

// Expected Output: Daily cost aggregates matching invoice
```

**Evidence**: Export query results as CSV, save to `out/adx-validation-queries/`

**Screenshot Required**: ADX Web Explorer showing table list and sample query results

---

## 5. APIM Validation

### 5.1 List APIM Instances

**Purpose**: Confirm APIM resource exists.

```powershell
# Command
az apim list \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/apim-instances.json"

# Expected Output: marco-sandbox-apim
```

**Validation Points**:
- [ ] Service name: `marco-sandbox-apim`
- [ ] SKU: Developer, Standard, or Premium
- [ ] Location: canadacentral
- [ ] Gateway URL: `https://marco-sandbox-apim.azure-api.net`

**Evidence Artifact**: `apim-instances.json`

---

### 5.2 List APIM APIs

**Purpose**: Enumerate APIs for policy configuration.

```powershell
# Command
az apim api list \
  --service-name marco-sandbox-apim \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/apim-apis.json"

# Expected Output: List of APIs with display names, paths
```

**Validation Points**:
- [ ] At least 1 API exists for testing
- [ ] API path, version, protocols (HTTP/HTTPS)

**Evidence Artifact**: `apim-apis.json`

**Screenshot Required**: Portal → APIM → APIs blade

---

### 5.3 Check Base Policy Configuration

**Purpose**: Validate if cost attribution headers are injected.

**Manual Steps** (Azure Portal):
1. Navigate to APIM → APIs → "All APIs"
2. Open "Inbound processing" policy editor
3. Look for `<set-variable>` or `<set-header>` elements extracting:
   - `x-eva-costcenter`
   - `x-eva-caller-app`
   - `x-eva-environment`

**Evidence**: Export policy XML and save to `out/apim-base-policy.xml`

**Validation Points**:
- [CURRENT] Policy likely does NOT have these headers (meets UNKNOWN status)
- [TARGET] Policy injects headers with defaults for missing values

---

### 5.4 Check Application Insights Integration

**Purpose**: Verify telemetry logging is enabled.

```powershell
# Command
az apim logger list \
  --service-name marco-sandbox-apim \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/apim-loggers.json"

# Expected Output: Logger linked to App Insights resource
```

**Validation Points**:
- [ ] Logger type: applicationInsights
- [ ] Resource ID: App Insights instrumentation key or connection string
- [ ] Sampling: 100% (for accurate cost attribution)

**Evidence Artifact**: `apim-loggers.json`

**Screenshot Required**: Portal → APIM → Application Insights blade showing diagnostics settings

---

## 6. Cost Management Exports

### 6.1 List Configured Exports

**Purpose**: Enumerate active cost exports for both subscriptions.

```powershell
# Command for EsDAICoESub (dev/stage)
az costmanagement export list \
  --scope "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba" \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/cost-exports-dev.json"

# Command for EsPAICoESub (prod)
az costmanagement export list \
  --scope "/subscriptions/802d84ab-3189-4221-8453-fcc30c8dc8ea" \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/cost-exports-prod.json"

# Expected Output: EsDAICoESub-Daily, EsPAICoESub-Daily
```

**Validation Points**:
- [ ] Export name: `EsDAICoESub-Daily`, `EsPAICoESub-Daily`
- [ ] Schedule: Daily, 1 AM UTC
- [ ] Destination: Storage account `marcosandboxfinopshub`, container `costs`
- [ ] Format: CSV
- [ ] Schema version: 2024-08-01 (ActualCost with tags)
- [ ] Status: Active

**Evidence Artifacts**: `cost-exports-dev.json`, `cost-exports-prod.json`

**Screenshot Required**: Portal → Cost Management → Exports showing run history

---

### 6.2 Validate Export Run History

**Purpose**: Confirm recent successful executions.

**Manual Steps** (Azure Portal):
1. Navigate to Cost Management → Exports
2. Select export (e.g., `EsDAICoESub-Daily`)
3. View run history tab
4. Check last 7 days for status (Succeeded) and file size

**Evidence**: Screenshot showing:
- [ ] Last run date: Within 24 hours
- [ ] Status: Succeeded
- [ ] File size: >1 MB (indicates data)
- [ ] Execution time: <5 minutes

---

## 7. RBAC and Permissions

### 7.1 Check Role Assignments on Storage

**Purpose**: Validate permissions for ADF managed identity (post-deployment).

```powershell
# Command
az role assignment list \
  --scope "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Storage/storageAccounts/marcosandboxfinopshub" \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/storage-rbac.json"

# Expected Output (future): mi-finops-adf with Storage Blob Data Contributor
```

**Validation Points**:
- [ ] Principal: Managed identity for ADF (`mi-finops-adf`)
- [ ] Role: Storage Blob Data Contributor
- [ ] Scope: Storage account `marcosandboxfinopshub`

**Evidence Artifact**: `storage-rbac.json`

---

### 7.2 Check Role Assignments on ADX

**Purpose**: Validate database ingestor role for ADF (post-deployment).

```kql
// Execute in ADX Web Explorer
.show database finopsdb principals

// Expected Output: mi-finops-adf with role "ingestor"
```

**Evidence**: Export query result to `out/adx-principals.csv`

---

### 7.3 Check Current User Permissions

**Purpose**: Document user's RBAC roles for audit trail.

```powershell
# Command
az role assignment list \
  --assignee marco.presta@hrsdc-rhdcc.gc.ca \
  --include-inherited \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/user-rbac.json"

# Expected Output: Reader on subscriptions, potentially Contributor on sandbox RG
```

**Validation Points**:
- [ ] Subscription-level: Reader (minimum)
- [ ] Resource group-level: Contributor (if managing resources)
- [ ] Limitations: Cannot assign roles (requires Owner or User Access Administrator)

**Evidence Artifact**: `user-rbac.json`

---

## 8. Monitoring and Diagnostics

### 8.1 Check Application Insights Availability

**Purpose**: Confirm App Insights exists for APIM logging.

```powershell
# Command
az monitor app-insights component list \
  --resource-group EsDAICoE-Sandbox \
  --output json | Out-File -FilePath "i:/eva-foundation/14-az-finops/tools/finops/out/appinsights.json"

# Expected Output: App Insights resource (if exists)
```

**Validation Points**:
- [ ] Component name: `marco-sandbox-appinsights` (or similar)
- [ ] Application type: web
- [ ] Instrumentation key: Non-empty
- [ ] Connection string: Available

**Evidence Artifact**: `appinsights.json`

---

### 8.2 Query Sample Telemetry

**Purpose**: Validate APIM request logs in App Insights (post-policy deployment).

**KQL Query** (execute in Portal → App Insights → Logs):

```kql
requests
| where timestamp > ago(24h)
| where cloud_RoleName == "APIM-marco-sandbox-apim"
| extend CostCenter = tostring(customDimensions["x-eva-costcenter"])
| extend CallerApp = tostring(customDimensions["x-eva-caller-app"])
| summarize RequestCount=count() by CostCenter, CallerApp
| order by RequestCount desc
```

**Evidence**: Export query result as CSV to `out/appinsights-apim-telemetry.csv`

**Validation Points**: If query returns no results, cost attribution headers are NOT configured yet.

---

## 9. Summary Checklist

**Use this checklist to track evidence collection progress:**

| Component | Evidence Artifact | Status | Notes |
|-----------|-------------------|--------|-------|
| Storage Accounts | `storage-accounts.json` | ⬜ Not Collected | Run command in section 1.1 |
| Storage Containers | `storage-containers.json` | ⬜ Not Collected | Run command in section 1.2 |
| Storage Network Rules | `storage-network.json` | ⬜ Not Collected | Run command in section 1.4 |
| Event Grid Topics | `eventgrid-system-topics.json` | ⬜ Not Collected | Run command in section 2.1 |
| Event Subscriptions | `eventgrid-subscriptions.json` | ⬜ Not Collected | Run command in section 2.2 |
| ADF Factories | `adf-factories.json` | ⬜ Not Collected | Run command in section 3.1 |
| ADF Pipelines | `adf-pipelines.json` | ⬜ Not Collected | Run command in section 3.2 |
| ADF Triggers | `adf-triggers.json` | ⬜ Not Collected | Run command in section 3.3 |
| ADX Clusters | `adx-clusters.json` | ⬜ Not Collected | Run command in section 4.1 |
| ADX Databases | `adx-databases.json` | ⬜ Not Collected | Run command in section 4.2 (post-deploy) |
| APIM Instances | `apim-instances.json` | ⬜ Not Collected | Run command in section 5.1 |
| APIM APIs | `apim-apis.json` | ⬜ Not Collected | Run command in section 5.2 |
| APIM Base Policy | `apim-base-policy.xml` | ⬜ Not Collected | Manual export (section 5.3) |
| APIM Loggers | `apim-loggers.json` | ⬜ Not Collected | Run command in section 5.4 |
| Cost Exports (Dev) | `cost-exports-dev.json` | ⬜ Not Collected | Run command in section 6.1 |
| Cost Exports (Prod) | `cost-exports-prod.json` | ⬜ Not Collected | Run command in section 6.1 |
| Storage RBAC | `storage-rbac.json` | ⬜ Not Collected | Run command in section 7.1 |
| User RBAC | `user-rbac.json` | ⬜ Not Collected | Run command in section 7.3 |
| App Insights | `appinsights.json` | ⬜ Not Collected | Run command in section 8.1 |

---

## 10. Automation Script

**Convenience Script**: Execute all CLI commands in batch.

See: `i:/eva-foundation/14-az-finops/tools/finops/az-inventory-finops.ps1`

**Usage**:
```powershell
cd i:/eva-foundation/14-az-finops/tools/finops
.\az-inventory-finops.ps1

# Output: All JSON files written to out/ directory
# Duration: ~2 minutes
```

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-02-17 08:20 AM ET | Marco Presta | Initial evidence pack with validation commands |

---

**Document Status**: Ready for execution  
**Next Action**: Run commands, collect artifacts, generate screenshots
