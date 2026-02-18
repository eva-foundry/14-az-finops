# Exportation Best Practices - Azure Cost Data

**Location**: I:\eva-foundation\14-az-finops\docs\EXPORTATION-BEST-PRACTICES.md

Date: 2026-02-16

Purpose: Consolidated FinOps best-practices for exporting Azure cost data, recommended configuration for production, and fallback options when SDKs are unreliable.

1. Recommended approach
- Use native Azure Cost Management Exports for ongoing, scheduled, reliable daily exports to Blob Storage. This is the preferred production solution: minimal maintenance, reliable, and provides complete data.
- For historical backfill or custom queries that require real-time or ad-hoc extraction, use Azure REST API (not the Python SDK) to avoid SDK pagination bugs.

2. Export configuration (production)
- Frequency: Daily (previous day) at ~02:00 UTC
- Granularity: Daily
- Output format: CSV with FOCUS/FOCUS-like schema if available (UsageDate, SubscriptionId, SubscriptionName, ResourceGroup, ResourceId, ResourceType, PreTaxCost, Currency, Tags...)
- Destination: Centralized storage account (e.g., `marcosandboxfinopshub`) in container `costs/historical/{subscription}/{YYYY-MM}/`
- Retention/Lifecycle: Move to Cool after 90 days, Archive after 365 days

3. Scheduling
- Create separate export per subscription. Use management-group export only if you need consolidated export and have management-group permissions.
- Set up daily export via `az costmanagement export create` or via Azure Portal. Example:

```powershell
az costmanagement export create \
  --name "EsDAICoE-Daily" \
  --scope "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba" \
  --storage-account-id "/subscriptions/..../resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/marcosandboxfinopshub" \
  --storage-container "costs" \
  --timeframe "MonthToDate" \
  --recurrence "Daily"
```

4. Historical backfill (best practice)
- Use the Azure REST API for backfill to avoid SDK pagination limitations. Implement robust pagination handling using `nextLink` and exponential backoff for 429/5xx responses. Upload each month's output to blob storage under `historical/by-rest/{subscription}/{YYYY-MM}/` for traceability.

5. Schema & completeness checks
- Required columns: `UsageDate, SubscriptionId, SubscriptionName, ResourceGroup, ResourceId, ResourceType, MeterCategory, PreTaxCost, Currency`
- Recommended additional columns: `Tags, UnitOfMeasure, Quantity, EffectivePrice, MeterName, ChargeType`
- Perform daily completeness checks: no missing dates, expected row counts, tag coverage.

6. Storage & lifecycle
- Output pattern: `costs/{subscription}/historical/{YYYY-MM}/costs_{YYYY-MM}_Part{n}.csv` for chunked outputs or `costs_{YYYY-MM}_FULL.csv` for merged files.
- Lifecycle policy: Cool after 90 days, Archive after 365 days.

7. Monitoring & alerting
- Create budgets and alerts per subscription and resource group.
- Monitor cost export job status and automate retries/alerts on failures.

8. When SDK is used (not recommended for large datasets)
- If using `extract_costs_sdk.py`, keep chunks small (2-day chunks found necessary due to SDK pagination). Prefer REST API or Cost Management Exports for production.

9. References
- docs/SDK-PAGINATION-LIMITATION.md
- docs/QUICK-START-10DAY-CHUNKING.md
- docs/IMPLEMENTATION-COMPLETE-10DAY.md

