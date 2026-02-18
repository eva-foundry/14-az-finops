# Historical Backfill Test Results

**Date**: February 16, 2026  
**Test Scope**: 1-month backfill (January 2026) for both subscriptions  
**Script**: `scripts/Backfill-Costs-REST.ps1`

## Test Execution Summary

### Status: ✅ SUCCESS

The REST API backfill script successfully retrieved historical cost data after resolving multiple technical issues.

### Issues Resolved

1. **PowerShell Hashtable Syntax** (lines 100-110)
   - Problem: Mixed JSON-style comma separators with PowerShell hashtable
   - Fix: Restructured to proper PowerShell syntax with newline separators

2. **Variable Interpolation** (line 122)
   - Problem: `$monthKey:` parsed as invalid variable modifier
   - Fix: Changed to `${monthKey}` with explicit variable delimiter

3. **Date Formatting Complexity** (lines 102-104)
   - Problem: Complex ToString() expressions in hashtable causing parser errors
   - Fix: Extracted to separate `$fromDate` and `$toDate` variables

4. **Content-Type Header Missing** (line 52)
   - Problem: Azure API returned HTTP 415 "Unsupported Media Type"
   - Fix: Added `--headers "Content-Type=application/json"` to az rest call

5. **JSON Body Passing** (lines 46-53)
   - Problem: PowerShell string escaping issues when passing JSON directly
   - Fix: Write JSON to temp file and use `--body "@tempfile.json"` syntax

### Results

**EsDAICoESub** (d2d4e571-e0f2-4f6c-901a-f88f7669bcba):
- ✅ 31 rows retrieved (daily granularity for 31 days in January 2026)
- ✅ Output: `output/historical/EsDAICoESub/costs_2026-01_REST.csv`
- ✅ Data structure: PreTaxCost, Currency, UsageDate

**EsPAICoESub** (802d84ab-3189-4221-8453-fcc30c8dc8ea):
- ✅ 31 rows retrieved (daily granularity for 31 days in January 2026)
- ✅ Output: `output/historical/EsPAICoESub/costs_2026-01_REST.csv`
- ✅ Data structure: PreTaxCost, Currency, UsageDate

### Sample Data

```csv
"PreTaxCost","Currency","UsageDate"
"638.917882893963","CAD","20260101"
"711.207533532514","CAD","20260102"
"652.705483598071","CAD","20260103"
```

## Data Structure Comparison

### REST API Backfill Data
**Columns**: 3
- PreTaxCost
- Currency
- UsageDate

**Granularity**: Daily aggregated totals  
**Use Case**: High-level trend analysis, monthly cost totals

### Native Cost Management Export
**Columns**: 55+
- InvoiceSectionName, AccountName, AccountOwnerId
- SubscriptionId, SubscriptionName
- ResourceGroup, ResourceLocation, ResourceId, ResourceName
- Date, ProductName, MeterCategory, MeterSubCategory
- MeterId, MeterName, MeterRegion
- UnitOfMeasure, Quantity, EffectivePrice
- CostInBillingCurrency, CostCenter
- ConsumedService, Tags
- OfferId, AdditionalInfo
- ServiceInfo1, ServiceInfo2
- ReservationId, ReservationName
- UnitPrice, ProductOrderId, ProductOrderName
- Term, PublisherType, PublisherName
- ChargeType, Frequency, PricingModel
- AvailabilityZone, BillingAccountId, BillingAccountName
- BillingCurrencyCode, BillingPeriodStartDate, BillingPeriodEndDate
- BillingProfileId, BillingProfileName, InvoiceSectionId
- IsAzureCreditEligible, PartNumber, PayGPrice
- PlanName, ServiceFamily, CostAllocationRuleName
- benefitId, benefitName, ...

**Granularity**: Resource-level detailed records  
**File Size**: 30MB uncompressed (from 2.3MB gzipped) for partial month
**Use Case**: Detailed cost analysis, chargeback, optimization, tagging compliance

## Key Findings

1. **REST API Backfill Works**: Successfully retrieves daily aggregated cost data for trend analysis

2. **Native Exports Are Essential**: The daily exports configured via Azure Portal provide the detailed resource-level data needed for:
   - Resource group chargeback
   - Tag compliance analysis
   - SKU optimization recommendations
   - Idle resource identification
   - Service-level cost breakdowns

3. **Complementary Data Sources**:
   - **REST API backfill**: Historical trend data (12 months of daily totals)
   - **Native exports**: Detailed current data (resource-level granularity)

## Recommendations

### Immediate Actions

1. **Execute 12-Month Backfill**
   ```powershell
   .\scripts\Backfill-Costs-REST.ps1 -MonthsToBackfill 12 -InterRequestDelay 2
   ```
   - Retrieves: March 2025 through February 2026
   - Output: 24 CSV files (12 months × 2 subscriptions)
   - Purpose: Complete historical cost trend data

2. **Download and Archive Native Exports**
   ```powershell
   # Download existing export files from blob storage
   az storage blob download --account-name marcosandboxfinopshub \
     --container-name costs \
     --name "EsDAICoESub/EsDAICoESub-Daily/20260201-20260228/*/part_*.csv.gz" \
     --file "exports/EsDAICoESub-Feb2026.csv.gz" \
     --auth-mode login
   ```

3. **Monitor Daily Exports**
   - Verify daily exports continue to run successfully
   - Set up automated download/archival process
   - Implement retention policy for historical export files

### Phase 3: Power BI Dashboards

**Primary Data Source**: Native Cost Management Exports (detailed resource-level data)

**Dashboards to Build**:
1. **Executive Summary**
   - Monthly cost trend (REST API backfill data)
   - Current month vs. budget
   - Top 10 cost drivers by resource group
   - Cost by subscription

2. **Resource Group Chargeback**
   - Cost breakdown by resource group
   - Tagged vs. untagged resources
   - Cost allocation by CostCenter tag

3. **Service Analysis**
   - Cost by ConsumedService (Compute, Storage, Networking, etc.)
   - MeterCategory breakdown
   - Reserved instance utilization

4. **Optimization Opportunities**
   - Untagged resources
   - Idle resources (VMs, storage accounts)
   - SKU rightsizing candidates
   - Resource groups with highest cost growth

5. **Compliance Dashboard**
   - Tag compliance percentage
   - Resources missing required tags (CostCenter, Project, Environment)
   - Unmanaged resources (no owner tag)

### Phase 4: Cost Optimization

**Analysis Areas**:
1. Identify resources with zero usage/traffic
2. Find oversized VMs and storage accounts
3. Detect duplicate/redundant resources
4. Calculate reserved instance savings opportunities
5. Analyze cost trends by service for anomaly detection

## Next Steps

1. ✅ **Phase 1 COMPLETE**: Daily exports active for both subscriptions
2. ✅ **Phase 2 - Test**: 1-month backfill successful
3. ⏳ **Phase 2 - Execute**: Run 12-month full backfill
4. 📋 **Phase 3**: Power BI dashboard development (use native exports)
5. 📋 **Phase 4**: Cost optimization analysis

## Technical Notes

### REST API Query Body Structure

```json
{
  "type": "ActualCost",
  "timeframe": "Custom",
  "timePeriod": {
    "from": "2026-01-01T00:00:00Z",
    "to": "2026-01-31T23:59:59Z"
  },
  "dataset": {
    "granularity": "Daily",
    "aggregation": {
      "totalCost": {
        "name": "PreTaxCost",
        "function": "Sum"
      }
    }
  }
}
```

### Rate Limiting Strategy

- **Inter-request delay**: 2 seconds (configurable via `-InterRequestDelay`)
- **Pagination**: Automatic via `nextLink` property
- **Rate limit**: ~30 requests/minute (Azure Cost Management API)
- **12-month backfill**: ~48 requests total (24 months × 2 subscriptions, assuming no pagination)
- **Estimated duration**: ~3-4 minutes

### File Naming Convention

**REST API Backfill**: `costs_{YYYY-MM}_REST.csv`  
**Native Exports**: `{SubscriptionName}-Daily/{DateRange}/{GUID}/part_0_0001.csv.gz`

---

**Conclusion**: The REST API backfill script is working correctly and provides valuable historical trend data. Combined with the detailed native exports, we now have complete data coverage for Power BI dashboard implementation and cost optimization analysis.
