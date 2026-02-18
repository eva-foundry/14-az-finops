# Monthly Export Scripts for EsPAICoESub

**Purpose**: Automate creation and download of 12 months of historical cost data (Feb 2025 - Jan 2026) for Power BI analysis.

## Prerequisites

1. **Azure CLI authenticated**: 
   ```powershell
   az login --use-device-code --tenant bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8
   # Use: marco.presta@hrsdc-rhdcc.gc.ca
   ```

2. **Correct subscription**:
   ```powershell
   az account set --subscription "802d84ab-3189-4221-8453-fcc30c8dc8ea"
   az account show
   ```

3. **Permissions**: Cost Management Contributor (minimum)

## Step 1: Create Monthly Exports

Creates 12 one-time export definitions in Azure Cost Management.

```powershell
cd I:\eva-foundation\14-az-finops\scripts

# Preview without creating (dry run)
.\Create-Monthly-Exports-EsPAICoESub.ps1 -DryRun

# Create all 12 exports
.\Create-Monthly-Exports-EsPAICoESub.ps1
```

**What it does**:
- Creates exports: `EsPAICoESub-2025-02` through `EsPAICoESub-2026-01`
- Uses schema version: `2024-08-01` (matches daily export)
- Triggers immediate execution for each export
- Stores in: `marcosandboxfinopshub/costs/EsPAICoESub/EsPAICoESub-YYYY-MM/`

**Expected output**:
```
[INFO] Creating monthly exports for EsPAICoESub
[INFO] Total exports to create: 12
[PASS] Export created successfully
[PASS] Export execution triggered
...
[PASS] Successfully created: 12
```

## Step 2: Wait for Completion

Exports take 5-10 minutes to complete.

**Check status in Azure Portal**:
1. Navigate to: Cost Management + Billing → Cost Management → Exports
2. View: Export history
3. Wait for all exports to show "Succeeded" status

**Alternative - Check via CLI**:
```powershell
az rest --method GET --uri "https://management.azure.com/subscriptions/802d84ab-3189-4221-8453-fcc30c8dc8ea/providers/Microsoft.CostManagement/exports?api-version=2023-08-01" --query "value[?contains(name, '2025') || contains(name, '2026')].{Name:name, Status:properties.schedule.status, LastRun:properties.runHistory.value[0].status}"
```

## Step 3: Download and Process

Downloads all completed exports, decompresses them, and optionally combines into single file.

```powershell
# Download all exports
.\Download-Monthly-Exports-EsPAICoESub.ps1

# Download and combine into single file
.\Download-Monthly-Exports-EsPAICoESub.ps1 -CombineFiles

# Re-combine existing files (without re-downloading)
.\Download-Monthly-Exports-EsPAICoESub.ps1 -SkipDownload -CombineFiles
```

**What it does**:
- Lists blobs in storage: `EsPAICoESub/EsPAICoESub-YYYY-MM/`
- Downloads `.csv.gz` files via Azure CLI
- Decompresses using GZipStream
- Validates row counts and file sizes
- Combines into `EsPAICoESub-combined-12months.csv` (if `-CombineFiles` flag used)

**Expected output**:
```
[INFO] Processing EsPAICoESub-2025-02...
[INFO] Downloading 2.42 MB...
[PASS] Downloaded successfully
[INFO] Decompressing...
[PASS] Decompressed: 35.73 MB, 16587 data rows
...
[PASS] Combined file created successfully
[INFO] Size: 428.76 MB
[INFO] Total data rows: 198,564
```

## Output Structure

```
I:\eva-foundation\14-az-finops\output\EsPAICoESub-historical\
├── EsPAICoESub-2025-02.csv          (35.73 MB, 16,587 rows)
├── EsPAICoESub-2025-03.csv
├── EsPAICoESub-2025-04.csv
├── ...
├── EsPAICoESub-2026-01.csv
└── EsPAICoESub-combined-12months.csv (428+ MB, 198K+ rows)
```

## Data Structure (57 Columns)

**Key columns for Power BI**:
- `Date` - Time dimension
- `CostInBillingCurrency` - Cost amount
- `ResourceId` - Full Azure resource path
- `ResourceGroup` - Grouping dimension
- `SubscriptionName` - Subscription identifier
- `MeterCategory` - Service category (e.g., "Storage", "Compute")
- `Tags` - JSON with metadata (team, environment, cost center, etc.)
- `ConsumedService` - Service namespace (e.g., "Microsoft.Storage")
- `ResourceName` - Resource display name

**Full column list**: See `feb2025_full.csv` header in verify-export-format folder

## Troubleshooting

### Export Creation Fails

**Error**: "No export found" or HTTP 404
- **Cause**: Export name doesn't exist yet (normal for first creation)
- **Solution**: Script creates new export automatically

**Error**: HTTP 403 Forbidden
- **Cause**: Insufficient permissions
- **Solution**: Verify Cost Management Contributor role assignment

### Download Fails

**Error**: "Blob not found"
- **Cause**: Export still running or failed
- **Solution**: Check export status in Portal, wait for completion

**Error**: Zero-byte file after decompression
- **Cause**: Portal browser download truncated file
- **Solution**: Script uses Azure CLI (more reliable than Portal download)

### Combined File Issues

**Error**: Header mismatch
- **Cause**: Different schema versions between months
- **Solution**: All exports use same `2024-08-01` schema - should not occur

**Error**: Missing data
- **Cause**: Some monthly exports not downloaded
- **Solution**: Review download summary, re-run script for missing months

## Power BI Import

**Recommended approach**:

1. **Use combined file** for simplicity:
   ```
   Power BI → Get Data → Text/CSV
   → Select: EsPAICoESub-combined-12months.csv
   → Transform data → Set column types
   ```

2. **Column transformations**:
   - `Date`: Change type to Date
   - `CostInBillingCurrency`: Change type to Decimal Number
   - `Tags`: Parse JSON (Power Query M function)
   - `Quantity`: Change type to Decimal Number

3. **Create relationships**:
   - Date table ← Date column
   - Resource dimension ← ResourceId

4. **Calculated columns**:
   ```DAX
   Month = FORMAT([Date], "YYYY-MM")
   CostUSD = [CostInBillingCurrency] / 1.35  // Adjust exchange rate
   ```

## Cleanup

**Remove temporary files**:
```powershell
# Keep combined file, remove individual monthly CSVs
Remove-Item "I:\eva-foundation\14-az-finops\output\EsPAICoESub-historical\EsPAICoESub-2025-*.csv"
```

**Delete export definitions** (after download complete):
```powershell
# Optional: Remove one-time exports from Azure Cost Management
$months = @("2025-02", "2025-03", "2025-04", "2025-05", "2025-06", "2025-07", "2025-08", "2025-09", "2025-10", "2025-11", "2025-12", "2026-01")
foreach ($month in $months) {
    az rest --method DELETE --uri "https://management.azure.com/subscriptions/802d84ab-3189-4221-8453-fcc30c8dc8ea/providers/Microsoft.CostManagement/exports/EsPAICoESub-$month?api-version=2023-08-01"
}
```

## Notes

- **Schema consistency**: All exports use `2024-08-01` dataset version (matches daily export)
- **Storage performance**: Download via Azure CLI more reliable than Portal browser
- **Decompression**: Uses .NET GZipStream (faster than 7-Zip subprocess)
- **File sizes**: ~2.4 MB compressed → ~35 MB uncompressed per month
- **Row counts**: ~16K rows per month (varies by resource usage)
- **Data retention**: Blob storage files retained indefinitely (audit trail)

## Related Files

- Original EsDAICoESub scripts (already created): `Create-Monthly-Exports-EsDAICoESub.ps1`, `Download-Monthly-Exports-EsDAICoESub.ps1`
- Format verification: `I:\eva-foundation\14-az-finops\verify-export-format\feb2025_full.csv`
- REST API workarounds: `18-azure-best\02-cost-management\Azure-REST-Functions.ps1`

---

**Author**: Marco Presta  
**Date**: 2026-02-17  
**Project**: 14-az-finops (FinOps Historical Data Analysis)
