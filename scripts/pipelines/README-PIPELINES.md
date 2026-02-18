# Data Factory Pipeline Definitions

**Created**: February 4, 2026  
**Purpose**: Process Cost Management export data for FinOps analysis  
**Target Data Factory**: `marco-sandbox-finops-adf` (EsDAICoE-Sandbox)

---

## Pipeline Overview

### 1. IngestDailyCosts.json
**Purpose**: Copy daily cost exports from blob storage to processing area  
**Frequency**: Triggered daily after Cost Management exports complete  
**Input**: `costs/esdaicoesub/exports/*.csv` and `costs/espaicoesub/exports/*.csv`  
**Output**: `costs/processed/{subscription}/*.csv`

**What it does**:
- Copies EsDAICoESub cost exports to `processed/esdaicoesub/`
- Copies EsPAICoESub cost exports to `processed/espaicoesub/`
- Maintains folder structure for tracking
- Handles wildcards for daily file naming variations

---

### 2. TransformCostData.json
**Purpose**: Clean, enrich, and transform cost data for analysis  
**Frequency**: Runs after IngestDailyCosts completes  
**Input**: `costs/processed/{subscription}/*.csv`  
**Output**: `costs/transformed/*.csv`

**What it does**:
- Standardizes column names and data types
- Adds calculated fields (daily cost, monthly projection)
- Enriches with resource metadata (tags, SKUs)
- Filters out zero-cost entries
- Deduplicates records

---

### 3. AggregateByResource.json
**Purpose**: Aggregate cost data by resource type, resource group, and subscription  
**Frequency**: Runs after TransformCostData completes  
**Input**: `costs/transformed/*.csv`  
**Output**: Multiple aggregated views in `costs/aggregated/`

**What it does**:
- **By Resource Type**: Groups by ResourceType, sums costs
- **By Resource Group**: Groups by ResourceGroupName, sums costs
- **Sandbox Only**: Filters to EsDAICoE-Sandbox resources specifically

**Output Files**:
- `aggregated/by-resource-type/costs-{date}.csv`
- `aggregated/by-resource-group/costs-{date}.csv`
- `aggregated/sandbox-only/costs-{date}.csv`

---

## Deployment Commands

### Prerequisites
1. Storage account exists: `marcosandboxfinopshub`
2. Data Factory exists: `marco-sandbox-finops-adf`
3. Cost exports configured and running
4. Storage Blob Data Contributor role granted

### Deploy Pipelines

```bash
cd I:\eva-foundation\14-az-finops\scripts\pipelines

# Deploy Pipeline 1: IngestDailyCosts
az datafactory pipeline create \
  --resource-group EsDAICoE-Sandbox \
  --factory-name marco-sandbox-finops-adf \
  --name IngestDailyCosts \
  --pipeline @IngestDailyCosts.json

# Deploy Pipeline 2: TransformCostData
az datafactory pipeline create \
  --resource-group EsDAICoE-Sandbox \
  --factory-name marco-sandbox-finops-adf \
  --name TransformCostData \
  --pipeline @TransformCostData.json

# Deploy Pipeline 3: AggregateByResource
az datafactory pipeline create \
  --resource-group EsDAICoE-Sandbox \
  --factory-name marco-sandbox-finops-adf \
  --name AggregateByResource \
  --pipeline @AggregateByResource.json

# Verify deployment
az datafactory pipeline list \
  --resource-group EsDAICoE-Sandbox \
  --factory-name marco-sandbox-finops-adf \
  --output table
```

---

## Create Required Datasets

Before pipelines can run, create linked datasets:

```bash
# CostExportSource dataset (parameterized for folder paths)
az datafactory dataset create \
  --resource-group EsDAICoE-Sandbox \
  --factory-name marco-sandbox-finops-adf \
  --name CostExportSource \
  --properties '{
    "linkedServiceName": {
      "referenceName": "BlobStorageLinkedService",
      "type": "LinkedServiceReference"
    },
    "parameters": {
      "folderPath": {
        "type": "String"
      }
    },
    "type": "DelimitedText",
    "typeProperties": {
      "location": {
        "type": "AzureBlobStorageLocation",
        "folderPath": {
          "value": "@dataset().folderPath",
          "type": "Expression"
        },
        "container": "costs"
      },
      "columnDelimiter": ",",
      "escapeChar": "\\",
      "firstRowAsHeader": true,
      "quoteChar": "\""
    }
  }'

# Similar for ProcessedCostData, TransformedCostData, AggregatedCostData...
```

---

## Manual Pipeline Trigger (Testing)

```bash
# Trigger pipeline manually
az datafactory pipeline create-run \
  --resource-group EsDAICoE-Sandbox \
  --factory-name marco-sandbox-finops-adf \
  --pipeline-name IngestDailyCosts

# Check run status
az datafactory pipeline-run show \
  --resource-group EsDAICoE-Sandbox \
  --factory-name marco-sandbox-finops-adf \
  --run-id <run-id>
```

---

## Scheduled Triggers

Create trigger to run pipelines daily after Cost Management exports complete (typically 2 AM UTC):

```json
{
  "name": "DailyCostProcessingTrigger",
  "properties": {
    "type": "ScheduleTrigger",
    "typeProperties": {
      "recurrence": {
        "frequency": "Day",
        "interval": 1,
        "startTime": "2026-02-05T02:30:00Z",
        "timeZone": "UTC"
      }
    },
    "pipelines": [
      {
        "pipelineReference": {
          "referenceName": "IngestDailyCosts",
          "type": "PipelineReference"
        }
      }
    ]
  }
}
```

---

## Data Flow Architecture

```
Cost Management Exports
    ↓
costs/esdaicoesub/exports/*.csv
costs/espaicoesub/exports/*.csv
    ↓
[IngestDailyCosts Pipeline]
    ↓
costs/processed/esdaicoesub/*.csv
costs/processed/espaicoesub/*.csv
    ↓
[TransformCostData Pipeline]
    ↓
costs/transformed/*.csv
    ↓
[AggregateByResource Pipeline]
    ↓
costs/aggregated/by-resource-type/*.csv
costs/aggregated/by-resource-group/*.csv
costs/aggregated/sandbox-only/*.csv
```

---

## Next Steps

1. **After permission granted**: Deploy pipelines
2. **Create datasets**: CostExportSource, ProcessedCostData, TransformedCostData, AggregatedCostData
3. **Create linked service**: BlobStorageLinkedService pointing to marcosandboxfinopshub
4. **Test manually**: Trigger IngestDailyCosts pipeline
5. **Set up schedule**: Create DailyCostProcessingTrigger
6. **Monitor**: Check pipeline runs in Azure Portal Data Factory UI

---

**Status**: Ready to deploy once Storage Blob Data Contributor permission granted  
**Estimated Setup Time**: 30 minutes (datasets + linked service + trigger)  
**Estimated Cost**: $2-5/month (Data Factory execution)
