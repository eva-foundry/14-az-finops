# 03 - Deployment Plan (IaC-First, Phased Approach)

**Document Type**: Deployment  
**Phase**: Planning  
**Audience**: [engineers, devops, architects]  
**Last Updated**: 2026-02-17 08:20 AM ET  
**Author**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Deployment Target**: EsDAICoE-Sandbox (canadacentral)

---

## Executive Summary

This deployment plan implements the FinOps Hubs target architecture over 4 phases (9 weeks total) using Infrastructure-as-Code (Bicep modules). Each phase has clear acceptance criteria, rollback procedures, and evidence requirements. Deployment follows enterprise best practices: least-privilege RBAC, private networking, and CI/CD automation.

**Key Constraints**:
- No Contributor/Owner on subscription → Deploy via Azure Portal + IaC templates (limited automation)
- Dev SKU resources to minimize cost during pilot
- Incremental approach to reduce risk and enable early validation

---

## Resource Naming Convention

All resources follow the pattern: `marco-{purpose}-{resourceType}[-{suffix}]`

| Resource Type | Name | Resource Group | Location |
|---------------|------|----------------|----------|
| Storage Account | `marcosandboxfinopshub` | EsDAICoE-Sandbox | canadacentral |
| Data Factory | `marco-sandbox-finops-adf` | EsDAICoE-Sandbox | canadacentral |
| ADX Cluster | `marcofinopsadx` | EsDAICoE-Sandbox | canadacentral |
| ADX Database | `finopsdb` | (within cluster) | canadacentral |
| Event Grid Topic | `marcosandboxfinopshub-{guid}` | esdaicoe-sandbox | canadacentral |
| Key Vault | `marcosandkv20260203` | EsDAICoE-Sandbox | canadacentral |
| Managed Identity (ADF) | `mi-finops-adf` | EsDAICoE-Sandbox | canadacentral |
| Managed Identity (PBI) | `mi-finops-powerbi` | EsDAICoE-Sandbox | canadacentral |
| Private Endpoint (Storage) | `pe-marcosandbox-blob` | EsDAICoE-Sandbox | canadacentral |
| Private Endpoint (ADX) | `pe-marcofinops-adx` | EsDAICoE-Sandbox | canadacentral |

---

## Phase 1: Foundation (Weeks 1-2)

**Objective**: Establish storage hierarchy, event routing, and validation framework.

### Tasks

#### 1.1 Storage Container Structure

**Action**: Create additional containers in `marcosandboxfinopshub`.

```bash
# Authenticate
az login --tenant 9ed55846-8a81-4246-acd8-b1a01abfc0d1 --use-device-code
az account set --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba

# Create containers
az storage container create --account-name marcosandboxfinopshub --name raw --auth-mode login
az storage container create --account-name marcosandboxfinopshub --name processed --auth-mode login
az storage container create --account-name marcosandboxfinopshub --name archive --auth-mode login
az storage container create --account-name marcosandboxfinopshub --name checkpoint --auth-mode login

# Verify
az storage container list --account-name marcosandboxfinopshub --auth-mode login -o table
```

**Acceptance Criteria**:
- [ ] 4 new containers visible in `az storage container list` output
- [ ] Container permissions: Private (no anonymous access)
- [ ] Test file upload succeeds in each container
- [ ] Evidence: Screenshot of Portal → Storage Account → Containers blade

#### 1.2 Storage Lifecycle Policy

**Action**: Configure auto-tiering to Cool/Archive.

**Bicep Module** (`storage-lifecycle.bicep`):
```bicep
param storageAccountName string = 'marcosandboxfinopshub'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'MoveRawToCool'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['raw/']
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 90
                }
              }
            }
          }
        }
        {
          name: 'MoveArchiveToArchive'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['archive/']
            }
            actions: {
              baseBlob: {
                tierToArchive: {
                  daysAfterModificationGreaterThan: 180
                }
                delete: {
                  daysAfterModificationGreaterThan: 2555  // 7 years
                }
              }
            }
          }
        }
      ]
    }
  }
}
```

**Deployment**:
```bash
az deployment group create \
  --resource-group EsDAICoE-Sandbox \
  --template-file storage-lifecycle.bicep \
  --parameters storageAccountName=marcosandboxfinopshub
```

**Acceptance Criteria**:
- [ ] Lifecycle policy visible in Portal → Storage Account → Lifecycle management
- [ ] Rule count: 2 (MoveRawToCool, MoveArchiveToArchive)
- [ ] Test: Upload file to `archive/`, verify tier change scheduled (check blob metadata)

#### 1.3 Migrate Existing Exports to Raw

**Action**: Reorganize current `costs/` blobs into `raw/costs/` hierarchy.

```bash
# List existing blobs
az storage blob list \
  --account-name marcosandboxfinopshub \
  --container-name costs \
  --auth-mode login \
  --query "[].name" -o tsv > existing-blobs.txt

# Copy to raw/ (example for EsDAICoESub)
while IFS= read -r blob; do
  echo "Copying $blob to raw/$blob..."
  az storage blob copy start \
    --account-name marcosandboxfinopshub \
    --destination-container raw \
    --destination-blob "costs/$blob" \
    --source-container costs \
    --source-blob "$blob" \
    --auth-mode login
done < existing-blobs.txt

# Verify copy completion (check for copyStatus=success)
# After verification, delete from costs/ (optional)
```

**Acceptance Criteria**:
- [ ] All blobs from `costs/` present in `raw/costs/` with same structure
- [ ] Original `costs/` container can be deleted or renamed to `costs-old`
- [ ] Export destinations updated to `raw/costs/` (Portal config update)

#### 1.4 Update Export Destinations (Portal)

**Action**: Reconfigure daily exports to target `raw/costs/` container.

**Portal Steps**:
1. Navigate to Cost Management → Exports
2. Select `EsDAICoESub-Daily` → Edit
3. Change Root Folder Path: `raw/costs/EsDAICoESub`
4. Save and trigger manual run
5. Repeat for `EsPAICoESub-Daily`

**Acceptance Criteria**:
- [ ] Next export lands in `raw/costs/EsDAICoESub/YYYY/MM/` (verify path)
- [ ] Event Grid receives `BlobCreated` event (check Event Grid Metrics)
- [ ] Evidence: Screenshot showing new export run history with updated path

---

## Phase 2: Analytics Infrastructure (Weeks 3-4)

**Objective**: Deploy ADX cluster, create schema, and implement ingestion pipelines.

### Tasks

#### 2.1 Deploy ADX Cluster

**Bicep Module** (`adx-cluster.bicep`):
```bicep
param clusterName string = 'marcofinopsadx'
param location string = 'canadacentral'
param skuName string = 'Dev(No SLA)_Standard_E2a_v4'
param skuCapacity int = 2

resource adxCluster 'Microsoft.Kusto/clusters@2023-08-15' = {
  name: clusterName
  location: location
  sku: {
    name: skuName
    tier: 'Basic'
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableStreamingIngest: true
    enablePurge: true
    publicNetworkAccess: 'Enabled'  // Phase 4: Change to 'Disabled' + private endpoint
    trustedExternalTenants: []
  }
}

resource adxDatabase 'Microsoft.Kusto/clusters/databases@2023-08-15' = {
  parent: adxCluster
  name: 'finopsdb'
  location: location
  kind: 'ReadWrite'
  properties: {
    softDeletePeriod: 'P1825D'  // 5 years
    hotCachePeriod: 'P31D'      // 31 days hot cache
  }
}

output clusterUri string = adxCluster.properties.uri
output databaseName string = adxDatabase.name
output principalId string = adxCluster.identity.principalId
```

**Deployment**:
```bash
az deployment group create \
  --resource-group EsDAICoE-Sandbox \
  --template-file adx-cluster.bicep \
  --parameters clusterName=marcofinopsadx location=canadacentral
```

**Acceptance Criteria**:
- [ ] Cluster status: Running (Portal → Azure Data Explorer Clusters)
- [ ] Database `finopsdb` visible
- [ ] Query editor accessible: `https://dataexplorer.azure.com/clusters/marcofinopsadx`
- [ ] Test query succeeds: `.show databases`
- [ ] Evidence: Screenshot of cluster overview + query result

#### 2.2 Create ADX Schema

**KQL Script** (`create-schema.kql`):
```kusto
// Connect to marcofinopsadx.canadacentral
// Database: finopsdb

// Table 1: raw_costs
.create table raw_costs (
    Date: datetime,
    SubscriptionId: string,
    SubscriptionName: string,
    ResourceGroup: string,
    ResourceId: string,
    ResourceName: string,
    ResourceLocation: string,
    ResourceType: string,
    MeterCategory: string,
    MeterSubCategory: string,
    MeterId: string,
    MeterName: string,
    Quantity: real,
    EffectivePrice: real,
    CostInBillingCurrency: real,
    BillingCurrency: string,
    Tags: dynamic,
    ConsumedService: string,
    IngestionTime: datetime
)

// Update policy: auto-add ingestion time
.alter table raw_costs policy update
  @'[{"IsEnabled": true, "Source": "IngestionTime", "Query": "raw_costs | extend IngestionTime = now()", "IsTransactional": true}]'

// Partitioning by Date (1 day partitions)
.alter table raw_costs policy partitioning
  @'{"PartitionKeys":[{"ColumnName":"Date","Kind":"UniformRange","Properties":{"RangeSize":"1.00:00:00"}}]}'

// Retention: 5 years
.alter table raw_costs policy retention
  @'{"SoftDeletePeriod":"1825.00:00:00","Recoverability":"Enabled"}'

// Ingestion mapping for CSV
.create table raw_costs ingestion csv mapping 'CostExportMapping'
'['
'{"column":"Date","DataType":"datetime","Properties":{"Ordinal":"0"}},'
'{"column":"SubscriptionName","DataType":"string","Properties":{"Ordinal":"2"}},'
'{"column":"ResourceGroup","DataType":"string","Properties":{"Ordinal":"3"}},'
'{"column":"ResourceId","DataType":"string","Properties":{"Ordinal":"4"}},'
'{"column":"ResourceName","DataType":"string","Properties":{"Ordinal":"5"}},'
'{"column":"ResourceLocation","DataType":"string","Properties":{"Ordinal":"6"}},'
'{"column":"MeterCategory","DataType":"string","Properties":{"Ordinal":"10"}},'
'{"column":"MeterSubCategory","DataType":"string","Properties":{"Ordinal":"11"}},'
'{"column":"MeterId","DataType":"string","Properties":{"Ordinal":"12"}},'
'{"column":"MeterName","DataType":"string","Properties":{"Ordinal":"13"}},'
'{"column":"Quantity","DataType":"real","Properties":{"Ordinal":"14"}},'
'{"column":"EffectivePrice","DataType":"real","Properties":{"Ordinal":"15"}},'
'{"column":"CostInBillingCurrency","DataType":"real","Properties":{"Ordinal":"20"}},'
'{"column":"Tags","DataType":"dynamic","Properties":{"Ordinal":"25"}},'
'{"column":"ConsumedService","DataType":"string","Properties":{"Ordinal":"30"}}'
']'

// Table 2: apim_usage
.create table apim_usage (
    Timestamp: datetime,
    ApiId: string,
    OperationId: string,
    ProductId: string,
    RequestId: string,
    CallerApp: string,
    CostCenter: string,
    Environment: string,
    HttpStatusCode: int,
    DurationMs: real
)

.alter table apim_usage policy retention
  @'{"SoftDeletePeriod":"365.00:00:00"}'

// Materialized view: normalized_costs
.create materialized-view normalized_costs on table raw_costs
{
    raw_costs
    | extend CostCenter = tostring(Tags.CostCenter)
    | extend Application = tostring(Tags.Application)
    | extend Environment = tostring(Tags.Environment)
    | extend Owner = tostring(Tags.owner)
    | project-away Tags
}

// Allocation function
.create-or-alter function AllocateCostByApp() {
    let usage = apim_usage
        | where Timestamp >= ago(1d)
        | summarize RequestCount = count() by CallerApp, bin(Timestamp, 1h);
    let costs = normalized_costs
        | where Date >= ago(1d)
        | where ResourceId has "/Microsoft.ApiManagement/"
        | summarize TotalCost = sum(CostInBillingCurrency) by bin(Date, 1h);
    usage
    | join kind=inner (costs) on $left.Timestamp == $right.Date
    | extend AllocatedCost = (RequestCount * 1.0 / toint(sum(RequestCount))) * TotalCost
    | project CallerApp, Timestamp, AllocatedCost, RequestCount
}
```

**Execution**:
```bash
# Via Azure Data Explorer portal or Kusto CLI
# Upload create-schema.kql and execute in finopsdb context
```

**Acceptance Criteria**:
- [ ] Tables created: `.show tables` returns `raw_costs`, `apim_usage`
- [ ] Materialized view: `.show materialized-views` returns `normalized_costs`
- [ ] Function exists: `.show functions` returns `AllocateCostByApp`
- [ ] Test ingestion: Upload sample CSV (5 rows) and verify row count

#### 2.3 Create Managed Identity for ADF

**Bicep Module** (`managed-identity.bicep`):
```bicep
param identityName string = 'mi-finops-adf'
param location string = 'canadacentral'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId
```

**Assign Roles**:
```bash
# Get managed identity principal ID
MI_PRINCIPAL_ID=$(az deployment group show -g EsDAICoE-Sandbox -n managed-identity --query properties.outputs.principalId.value -o tsv)

# Role 1: Storage Blob Data Contributor on marcosandboxfinopshub
az role assignment create \
  --assignee $MI_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Storage/storageAccounts/marcosandboxfinopshub"

# Role 2: ADX Database Ingestor on finopsdb
az kusto database-principal-assignment create \
  --cluster-name marcofinopsadx \
  --database-name finopsdb \
  --principal-id $MI_PRINCIPAL_ID \
  --principal-type App \
  --role Ingestor \
  --tenant-id $(az account show --query tenantId -o tsv) \
  --resource-group EsDAICoE-Sandbox \
  --principal-assignment-name adf-ingestor
```

**Acceptance Criteria**:
- [ ] Managed identity created: `az identity show -n mi-finops-adf -g EsDAICoE-Sandbox`
- [ ] Role assignments visible: `az role assignment list --assignee $MI_PRINCIPAL_ID -o table`
- [ ] ADX principal: `.show database finopsdb principals` includes mi-finops-adf

#### 2.4 Deploy ADF Ingestion Pipeline

**ADF Pipeline JSON** (`ingest-costs-to-adx.json`):
```json
{
  "name": "ingest-costs-to-adx",
  "properties": {
    "activities": [
      {
        "name": "CopyBlobToADX",
        "type": "Copy",
        "inputs": [
          {
            "referenceName": "BlobCSV",
            "type": "DatasetReference",
            "parameters": {
              "blobUrl": "@pipeline().parameters.blobUrl"
            }
          }
        ],
        "outputs": [
          {
            "referenceName": "ADXRawCosts",
            "type": "DatasetReference"
          }
        ],
        "typeProperties": {
          "source": {
            "type": "DelimitedTextSource",
            "storeSettings": {
              "type": "AzureBlobStorageReadSettings",
              "recursive": false
            },
            "formatSettings": {
              "type": "DelimitedTextReadSettings",
              "compressionCodec": "gzip"
            }
          },
          "sink": {
            "type": "AzureDataExplorerSink",
            "ingestionMappingName": "CostExportMapping"
          }
        }
      }
    ],
    "parameters": {
      "blobUrl": {
        "type": "string"
      }
    }
  }
}
```

**Deployment** (via Portal or `az datafactory` commands):
1. Open ADF Studio: `https://adf.azure.com/` → select `marco-sandbox-finops-adf`
2. Create datasets: `BlobCSV` (source), `ADXRawCosts` (sink)
3. Import pipeline JSON
4. Configure linked services (Storage + ADX) with managed identity auth
5. Test with sample blob URL

**Acceptance Criteria**:
- [ ] Pipeline visible in ADF Studio → Pipelines blade
- [ ] Test run succeeds with sample CSV (5 rows)
- [ ] ADX query confirms ingestion: `raw_costs | count` returns 5
- [ ] Evidence: Screenshot of successful pipeline run + ADX query result

---

## Phase 3: Attribution & Backfill (Weeks 5-7)

**Objective**: Implement APIM cost headers, ingest telemetry, and backfill 12 months of cost data.

### Tasks

#### 3.1 Configure APIM Base Policy

**Action**: Add cost attribution headers to all APIs.

**Portal Steps**:
1. Navigate to APIM → marco-sandbox-apim → APIs
2. Select "All APIs" → Policies → Inbound processing
3. Add XML policy (see [02-target-architecture.md](02-target-architecture.md#L600-L650))
4. Save and test with sample request (check App Insights for custom dimensions)

**Acceptance Criteria**:
- [ ] Policy visible in Portal → APIM → All APIs → Policies
- [ ] Test request includes header `x-costcenter: TESTVALUE`
- [ ] App Insights logs show custom dimension `customDimensions.x-eva-costcenter = TESTVALUE`
- [ ] Evidence: Screenshot of policy + App Insights log query result

#### 3.2 Configure APIM Diagnostics to App Insights

**CLI Command**:
```bash
az apim logger create \
  --service-name marco-sandbox-apim \
  --resource-group EsDAICoE-Sandbox \
  --logger-id marco-sandbox-appinsights \
  --logger-type applicationInsights \
  --resource-id "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Insights/components/marco-sandbox-appinsights"

az apim diagnostic create \
  --service-name marco-sandbox-apim \
  --resource-group EsDAICoE-Sandbox \
  --logger-id marco-sandbox-appinsights \
  --api-id '*' \
  --always-log allErrors \
  --sampling-percentage 100.0 \
  --verbosity information
```

**Acceptance Criteria**:
- [ ] Diagnostics setting visible: `az apim diagnostic list` returns 1+ entry
- [ ] Test request generates App Insights event within 60 seconds
- [ ] Query confirms: `requests | where customDimensions['x-eva-costcenter'] != ""`

#### 3.3 Create ADF Pipeline for APIM Telemetry Ingestion

**High-Level Steps**:
1. Create dataset: App Insights export (Kusto query or Blob export)
2. Create pipeline: `ingest-apim-telemetry` (scheduled daily)
3. Copy activity: App Insights → ADX `apim_usage` table
4. Enable and test

**Acceptance Criteria**:
- [ ] Pipeline runs daily at 3 AM UTC
- [ ] ADX table populated: `apim_usage | count` > 0
- [ ] Join test succeeds: `AllocateCostByApp() | take 10`

#### 3.4 Historical Backfill (12 Months)

**Action**: Execute backfill pipeline for Feb 2025 - Jan 2026.

```bash
# Trigger ADF pipeline: backfill-historical (manual)
az datafactory pipeline create-run \
  --factory-name marco-sandbox-finops-adf \
  --resource-group EsDAICoE-Sandbox \
  --name backfill-historical

# Monitor progress (check every 30 min)
az datafactory pipeline-run query-by-factory \
  --factory-name marco-sandbox-finops-adf \
  --resource-group EsDAICoE-Sandbox \
  --last-updated-after "2026-02-17T00:00:00Z" \
  --output table
```

**Acceptance Criteria**:
- [ ] Backfill completes in <4 hours (500 blobs / 5 parallel = 100 batches × 2 min)
- [ ] Row count matches expected: `raw_costs | summarize count() by bin(Date, 1d) | where Date >= datetime(2025-02-01)`
- [ ] No schema errors in pipeline logs
- [ ] Evidence: ADX query showing daily row counts (Feb 2025 - Jan 2026)

---

## Phase 4: Governance & Hardening (Weeks 8-9)

**Objective**: Enforce policies, enable private endpoints, and implement CI/CD.

### Tasks

#### 4.1 Deploy Azure Policy for Tag Enforcement

**Policy Definition JSON** (`require-costcenter-tag.json`):
```json
{
  "properties": {
    "displayName": "Require CostCenter tag on resources",
    "policyType": "Custom",
    "mode": "Indexed",
    "parameters": {},
    "policyRule": {
      "if": {
        "field": "tags['CostCenter']",
        "exists": "false"
      },
      "then": {
        "effect": "deny"
      }
    }
  }
}
```

**Deployment**:
```bash
az policy definition create \
  --name require-costcenter-tag \
  --rules require-costcenter-tag.json \
  --display-name "Require CostCenter tag" \
  --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba

az policy assignment create \
  --policy require-costcenter-tag \
  --scope "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox" \
  --name enforce-costcenter-sandbox
```

**Acceptance Criteria**:
- [ ] Policy appears in Portal → Policy → Assignments
- [ ] Test: Create resource without CostCenter tag → Deployment blocked
- [ ] Compliance report shows non-compliant resources (if any)

#### 4.2 Enable Private Endpoint for Storage

**Bicep Module** (`private-endpoint-storage.bicep`):
```bicep
// Requires VNet creation first (or use existing VNet)
param storageAccountName string = 'marcosandboxfinopshub'
param vnetName string = 'vnet-finops-canadacentral'
param subnetName string = 'subnet-privatelink'
param location string = 'canadacentral'

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.100.0.0/16']
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.100.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: 'pe-marcosandbox-blob'
  location: location
  properties: {
    subnet: {
      id: vnet.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: 'plsc-marcosandbox-blob'
        properties: {
          privateLinkServiceId: resourceId('Microsoft.Storage/storageAccounts', storageAccountName)
          groupIds: ['blob']
        }
      }
    ]
  }
}
```

**Acceptance Criteria**:
- [ ] Private endpoint created and approved
- [ ] Storage firewall updated: Deny public access, allow VNet only
- [ ] Test: Access from DevBox (in VNet) succeeds, public access fails

#### 4.3 CI/CD Pipeline for IaC Modules

**GitHub Actions Workflow** (`.github/workflows/deploy-finops.yml`):
```yaml
name: Deploy FinOps Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'infra/finops/**'
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Validate Bicep
        run: |
          az bicep build -f infra/finops/main.bicep
          az deployment group validate \
            --resource-group EsDAICoE-Sandbox \
            --template-file infra/finops/main.bicep
  
  deploy:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Deploy Infrastructure
        run: |
          az deployment group create \
            --resource-group EsDAICoE-Sandbox \
            --template-file infra/finops/main.bicep \
            --parameters @infra/finops/parameters.json
```

**Acceptance Criteria**:
- [ ] Workflow runs on PR and validates Bicep syntax
- [ ] Merge to main triggers deployment
- [ ] Deployment logs available in GitHub Actions
- [ ] Evidence: Screenshot of successful workflow run

---

## Rollback Procedures

### Phase 1 Rollback
- **Issue**: Lifecycle policy deletes active data
- **Action**:
  1. Disable policy: Portal → Storage → Lifecycle management → Disable rules
  2. Restore from GRS secondary (if within 14 days)
  3. Revert export paths to original `costs/` container

### Phase 2 Rollback
- **Issue**: ADX cluster cost exceeds budget
- **Action**:
  1. Stop ingestion: Disable ADF pipelines
  2. Deallocate cluster: `az kusto cluster stop`
  3. Revert to manual CSV analysis (Power BI import mode)

### Phase 3 Rollback
- **Issue**: APIM policy breaks production traffic
- **Action**:
  1. Remove policy: Portal → APIM → All APIs → Policies → Delete inbound section
  2. Verify traffic restored (check APIM metrics)
  3. Rollback diagnostics if causing latency

### Phase 4 Rollback
- **Issue**: Private endpoint blocks legitimate access
- **Action**:
  1. Enable public access temporarily: `az storage account update --default-action Allow`
  2. Investigate firewall rules
  3. Re-enable public access permanently if VNet integration fails

---

## Cost Summary (Incremental)

| Phase | New Resources | Monthly Cost (CAD) | One-Time Cost |
|-------|---------------|-------------------|---------------|
| Phase 1 | Containers + Lifecycle | $5 | $0 |
| Phase 2 | ADX Dev + MI + ADF | $330 | $0 |
| Phase 3 | APIM Diagnostics | $0 (existing) | $0 |
| Phase 4 | Private Endpoints | $15 | $0 |
| **Total** | | **$350/month** | **$0** |

**ROI Analysis**: $297K/month spend × 0.5% optimization = $1,485/month savings → 4.2x ROI.

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-02-17 08:20 AM ET | Marco Presta | Initial phased deployment plan with Bicep modules and acceptance criteria |

---

**Document Status**: Ready for Phase 1 execution  
**Next Review**: 2026-02-24 (after Phase 1 completion)
