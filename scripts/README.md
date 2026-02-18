# Monthly Export Automation - Multi-Subscription

**Purpose**: Automate creation and download of 12 months of historical cost data (Feb 2025 - Jan 2026) for Power BI analysis across multiple Azure subscriptions.

## Prerequisites

1. **Azure CLI authenticated**: 
   ```powershell
   az login --use-device-code --tenant bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8
   # Use: marco.presta@hrsdc-rhdcc.gc.ca
   ```

2. **Permissions**: Cost Management Contributor (minimum)

## Subscription Configuration

| Subscription | ID | Monthly Cost | Resources | Status |
|--------------|-----|--------------|-----------|--------|
| **EsDAICoESub** (Dev/Stage) | d2d4e571-e0f2-4f6c-901a-f88f7669bcba | ~$255K | 1,200+ | ✅ Complete |
| **EsPAICoESub** (Production) | 802d84ab-3189-4221-8453-fcc30c8dc8ea | ~$42K | 203 | Ready |

## Quick Commands

### EsDAICoESub (Dev/Stage) - Already Complete

```powershell
cd I:\eva-foundation\14-az-finops\scripts

# Download all 12 months and combine
.\Download-Monthly-Exports.ps1 `
    -SubscriptionId "d2d4e571-e0f2-4f6c-901a-f88f7669bcba" `
    -SubscriptionName "EsDAICoESub" `
    -CombineFiles
```

### EsPAICoESub (Production) - Ready to Process

```powershell
cd I:\eva-foundation\14-az-finops\scripts

# Step 1: Create all 12 exports (if not already done)
.\Create-Monthly-Exports.ps1 `
    -SubscriptionId "802d84ab-3189-4221-8453-fcc30c8dc8ea" `
    -SubscriptionName "EsPAICoESub"

# Step 2: Wait 5-10 minutes for completion (check Portal)

# Step 3: Download all 12 months and combine
.\Download-Monthly-Exports.ps1 `
    -SubscriptionId "802d84ab-3189-4221-8453-fcc30c8dc8ea" `
    -SubscriptionName "EsPAICoESub" `
    -CombineFiles
```

## Script Reference

### Create-Monthly-Exports.ps1

Creates 12 one-time export definitions in Azure Cost Management.

**Parameters**:
- `-SubscriptionId` (required): Azure subscription ID
- `-SubscriptionName` (required): Friendly name (e.g., "EsDAICoESub", "EsPAICoESub")
- `-StorageAccountName`: Target storage (default: marcosandboxfinopshub)
- `-ContainerName`: Container name (default: costs)
- `-StorageResourceGroup`: Storage RG (default: rg-sandbox-marco)
- `-DryRun`: Preview without creating

**What it does**:
- Creates exports: `{SubscriptionName}-2025-02` through `{SubscriptionName}-2026-01`
- Uses schema version: `2024-08-01` (verified format)
- Triggers immediate execution
- Stores in: `{StorageAccount}/{Container}/{SubscriptionName}/{SubscriptionName}-YYYY-MM/`

**Example**:
```powershell
# Preview
.\Create-Monthly-Exports.ps1 -SubscriptionId "d2d4e571-..." -SubscriptionName "EsDAICoESub" -DryRun

# Create
.\Create-Monthly-Exports.ps1 -SubscriptionId "d2d4e571-..." -SubscriptionName "EsDAICoESub"
```

### Download-Monthly-Exports.ps1

Downloads, decompresses, and combines export files.

**Parameters**:
- `-SubscriptionId` (required): Azure subscription ID
- `-SubscriptionName` (required): Friendly name
- `-StorageAccountName`: Source storage (default: marcosandboxfinopshub)
- `-ContainerName`: Container name (default: costs)
- `-OutputDir`: Download location (default: `output\{SubscriptionName}-historical`)
- `-CombineFiles`: Create single combined CSV
- `-SkipDownload`: Only combine existing files

**What it does**:
- Lists blobs in: `{SubscriptionName}/{SubscriptionName}-YYYY-MM/`
- Downloads `.csv.gz` files via Azure CLI (reliable method)
- Decompresses using GZipStream
- Validates row counts and sizes
- Optionally combines into single file: `{SubscriptionName}-combined-12months.csv`

**Example**:
```powershell
# Download only
.\Download-Monthly-Exports.ps1 -SubscriptionId "d2d4e571-..." -SubscriptionName "EsDAICoESub"

# Download and combine
.\Download-Monthly-Exports.ps1 -SubscriptionId "d2d4e571-..." -SubscriptionName "EsDAICoESub" -CombineFiles

# Re-combine existing files
.\Download-Monthly-Exports.ps1 -SubscriptionId "d2d4e571-..." -SubscriptionName "EsDAICoESub" -SkipDownload -CombineFiles
```

## Output Structure

```
I:\eva-foundation\14-az-finops\output\
├── EsDAICoESub-historical\                # Dev/Stage
│   ├── EsDAICoESub-2025-02.csv           (35.73 MB, 16,587 rows)
│   ├── EsDAICoESub-2025-03.csv
│   ├── ... (10 more months)
│   ├── EsDAICoESub-2026-01.csv
│   └── EsDAICoESub-combined-12months.csv (400-500 MB, ~190K rows)
│
└── EsPAICoESub-historical\                # Production
    ├── EsPAICoESub-2025-02.csv
    ├── EsPAICoESub-2025-03.csv
    ├── ... (10 more months)
    ├── EsPAICoESub-2026-01.csv
    └── EsPAICoESub-combined-12months.csv (200-300 MB, ~80K rows)
```

## Data Structure (57 Columns)

**Schema version**: `2024-08-01`

**Key columns for Power BI**:
- `Date` - Time dimension (MM/DD/YYYY format)
- `CostInBillingCurrency` - Cost amount in CAD
- `ResourceId` - Full Azure resource path
- `ResourceGroup` - Grouping dimension
- `SubscriptionId` - Subscription GUID
- `SubscriptionName` - Friendly subscription name
- `MeterCategory` - Service category (Storage, Compute, Networking, etc.)
- `ServiceFamily` - Service family grouping
- `ConsumedService` - Service namespace (Microsoft.Storage, Microsoft.Compute, etc.)
- `Tags` - JSON with metadata (team, environment, cost center, financial authority, etc.)
- `BillingAccountId`, `BillingProfileId`, `InvoiceSectionId` - Billing hierarchy
- `ProductName`, `MeterSubCategory`, `MeterName` - Product details

**Complete column list**: InvoiceSectionName, AccountName, AccountOwnerId, SubscriptionId, SubscriptionName, ResourceGroup, ResourceLocation, Date, ProductName, MeterCategory, MeterSubCategory, MeterId, MeterName, MeterRegion, UnitOfMeasure, Quantity, EffectivePrice, CostInBillingCurrency, CostCenter, ConsumedService, ResourceId, Tags, OfferId, AdditionalInfo, ServiceInfo1, ServiceInfo2, ResourceName, ReservationId, ReservationName, UnitPrice, ProductOrderId, ProductOrderName, Term, PublisherType, PublisherName, ChargeType, Frequency, PricingModel, AvailabilityZone, BillingAccountId, BillingAccountName, BillingCurrencyCode, BillingPeriodStartDate, BillingPeriodEndDate, BillingProfileId, BillingProfileName, InvoiceSectionId, IsAzureCreditEligible, PartNumber, PayGPrice, PlanName, ServiceFamily, CostAllocationRuleName, benefitId, benefitName, ResourceLocationNormalized, AccountId

## Check Export Status

**Via Azure Portal**:
1. Navigate to: Cost Management + Billing → Cost Management → Exports
2. Scope: Select subscription (EsDAICoESub or EsPAICoESub)
3. View: Export history
4. Look for: `{SubscriptionName}-2025-XX` exports with "Succeeded" status

**Via Azure CLI**:
```powershell
# EsDAICoESub
az rest --method GET `
  --uri "https://management.azure.com/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/providers/Microsoft.CostManagement/exports?api-version=2023-08-01" `
  --query "value[?contains(name, '2025') || contains(name, '2026')].{Name:name, LastStatus:properties.runHistory.value[0].status, LastRun:properties.runHistory.value[0].executionTime}"

# EsPAICoESub
az rest --method GET `
  --uri "https://management.azure.com/subscriptions/802d84ab-3189-4221-8453-fcc30c8dc8ea/providers/Microsoft.CostManagement/exports?api-version=2023-08-01" `
  --query "value[?contains(name, '2025') || contains(name, '2026')].{Name:name, LastStatus:properties.runHistory.value[0].status, LastRun:properties.runHistory.value[0].executionTime}"
```

## Troubleshooting

### Export Creation Fails

**Error**: HTTP 403 Forbidden
- **Cause**: Insufficient permissions
- **Solution**: Verify Cost Management Contributor role: `az role assignment list --assignee marco.presta@hrsdc-rhdcc.gc.ca --scope /subscriptions/{id}`

**Error**: Invalid storage resource ID
- **Cause**: Storage account in different subscription
- **Solution**: Verify storage RG parameter: `-StorageResourceGroup "rg-sandbox-marco"`

### Download Fails

**Error**: "Blob not found"
- **Cause**: Export still running or failed
- **Solution**: Check export status in Portal, wait for completion

**Error**: HTTP 403 when accessing storage
- **Cause**: Not authenticated or wrong account
- **Solution**: Re-authenticate: `az login --use-device-code`, use marco.presta@hrsdc-rhdcc.gc.ca

**Error**: Zero-byte file after decompression
- **Cause**: Corrupted download (should not occur with Azure CLI method)
- **Solution**: Delete `.csv.gz`, re-run download script

### Combined File Issues

**Error**: Header mismatch between months
- **Cause**: Different schema versions (should not occur)
- **Solution**: All exports use `2024-08-01` schema - verify in Portal

**Error**: Missing months
- **Cause**: Some exports incomplete
- **Solution**: Review download summary table, re-run for specific months

## Power BI Import

### Option 1: Combined File (Recommended)

```powershell
# Power BI Desktop → Get Data → Text/CSV
# Select: {SubscriptionName}-combined-12months.csv
```

**Power Query transformations**:
```M
// Change column types
= Table.TransformColumnTypes(Source,{
    {"Date", type date},
    {"CostInBillingCurrency", type number},
    {"Quantity", type number}
})

// Parse Tags JSON
= Table.AddColumn(#"Changed Type", "TagsParsed", each Json.Document([Tags]))
= Table.ExpandRecordColumn(#"Added TagsParsed", "TagsParsed", {"team", "environment", "app_id"})
```

### Option 2: Individual Monthly Files

```powershell
# Power BI Desktop → Get Data → Folder
# Select: I:\eva-foundation\14-az-finops\output\{SubscriptionName}-historical\
# Filter: *.csv (exclude *combined*)
# Combine & Transform
```

### Option 3: Multi-Subscription Combined

Combine both subscriptions for cross-subscription analysis:

```powershell
# In Power Query
= Table.Combine({
    Csv.Document(File.Contents("I:\eva-foundation\14-az-finops\output\EsDAICoESub-historical\EsDAICoESub-combined-12months.csv")),
    Csv.Document(File.Contents("I:\eva-foundation\14-az-finops\output\EsPAICoESub-historical\EsPAICoESub-combined-12months.csv"))
})
```

**DAX Calculated Columns**:
```DAX
Month = FORMAT([Date], "YYYY-MM")
Quarter = "Q" & QUARTER([Date]) & "-" & YEAR([Date])
CostUSD = [CostInBillingCurrency] / 1.35  // Adjust exchange rate
Team = PATHITEM(SUBSTITUTE([Tags], ",", "|"), 1, TEXT)  // Parse first tag
```

## Cleanup

**Remove individual monthly CSVs** (after combining):
```powershell
# Keep combined files only
Remove-Item "I:\eva-foundation\14-az-finops\output\EsDAICoESub-historical\EsDAICoESub-2025-*.csv"
Remove-Item "I:\eva-foundation\14-az-finops\output\EsPAICoESub-historical\EsPAICoESub-2025-*.csv"
```

**Delete export definitions** (optional, after download complete):
```powershell
# EsDAICoESub
$months = @("2025-02", "2025-03", "2025-04", "2025-05", "2025-06", "2025-07", "2025-08", "2025-09", "2025-10", "2025-11", "2025-12", "2026-01")
foreach ($month in $months) {
    az rest --method DELETE --uri "https://management.azure.com/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/providers/Microsoft.CostManagement/exports/EsDAICoESub-$month?api-version=2023-08-01"
}

# EsPAICoESub
foreach ($month in $months) {
    az rest --method DELETE --uri "https://management.azure.com/subscriptions/802d84ab-3189-4221-8453-fcc30c8dc8ea/providers/Microsoft.CostManagement/exports/EsPAICoESub-$month?api-version=2023-08-01"
}
```

## Notes

- **Schema consistency**: All exports use `2024-08-01` dataset version (matches daily exports)
- **Download reliability**: Azure CLI method more reliable than Portal browser (avoids truncation bug)
- **Decompression**: .NET GZipStream (faster than 7-Zip subprocess)
- **File sizes**: 
  - EsDAICoESub: ~2.4 MB compressed → ~35 MB uncompressed per month (~16K rows)
  - EsPAICoESub: ~1.5 MB compressed → ~20 MB uncompressed per month (~8K rows)
- **Data retention**: Blob storage files retained indefinitely (audit trail)
- **Cost**: Export execution and storage incurs minimal cost (~$0.01/month)

## Related Files

- **Scripts**: 
  - `Create-Monthly-Exports.ps1` (universal, subscription parameterized)
  - `Download-Monthly-Exports.ps1` (universal, subscription parameterized)
- **Legacy scripts** (deprecated): 
  - `Create-Monthly-Exports-EsDAICoESub.ps1` (superseded)
  - `Create-Monthly-Exports-EsPAICoESub.ps1` (superseded)
  - `Download-Monthly-Exports-EsDAICoESub.ps1` (superseded)
  - `Download-Monthly-Exports-EsPAICoESub.ps1` (superseded)
- **Format verification**: `I:\eva-foundation\14-az-finops\verify-export-format\feb2025_full.csv`
- **Azure REST API workarounds**: `I:\eva-foundation\18-azure-best\02-cost-management\Azure-REST-Functions.ps1`

---

**Author**: Marco Presta  
**Date**: 2026-02-17  
**Project**: 14-az-finops (FinOps Historical Data Analysis)  
**Version**: 2.0 (Multi-subscription parameterized scripts)
