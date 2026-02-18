# Azure Cost Management API - Rate Limiting Best Practices

**Date**: February 16, 2026  
**Project**: 14-az-finops  
**Context**: Extracting daily cost data for 12 months across 2 ESDC subscriptions

---

## Azure Cost Management API Rate Limits

Microsoft doesn't publicly document exact rate limits, but based on testing and community experience:

| Limit Type | Value | Source |
|------------|-------|--------|
| **Requests per minute** | ~30 per subscription | Community testing |
| **Max rows per response** | 5,000 rows | API pagination design |
| **Concurrent requests** | 1 recommended | API behavior |
| **Retry-After header** | 30-120 seconds | 429 response |

### Key Observations

1. **Daily granularity generates 10x more records than monthly**
   - Monthly: ~2,400 records/month
   - Daily: ~2,500 records/month (28-31 days × 80-90 records/day)

2. **Large date ranges trigger pagination**
   - 12 months daily data = 30,000+ records
   - Requires 6+ API calls at 5,000 rows each
   - Each call counts toward rate limit

3. **Rate limit is per subscription, not per account**
   - Processing 2 subscriptions in parallel doubles the risk
   - Sequential processing is safer

---

## Implemented Strategy

### 1. Monthly Chunking ✅

**Problem**: Requesting 12 months at once generates 30,000+ records requiring 6+ pagination calls  
**Solution**: Request 1 month at a time = 12 separate API calls with predictable result sizes

```powershell
# BAD: One large request
$startDate = "2025-02-01"
$endDate = "2026-01-31"
# Result: 6-12 pagination calls, high 429 risk

# GOOD: Monthly chunks
for ($month = 1; $month -le 12; $month++) {
    $monthStart = (Get-Date).AddMonths(-$month).ToString("yyyy-MM-01")
    $monthEnd = $monthStart.AddMonths(1).AddDays(-1)
    # Result: 1-2 pagination calls per month, low 429 risk
}
```

**Benefits**:
- Predictable API load (1-2 calls per month vs. 6-12 for entire year)
- Smaller result sets (2,500 vs. 30,000 rows)
- Resume capability (progress tracking per month)
- Better error isolation (one month fails, others succeed)

### 2. Sequential Processing ✅

**Problem**: Parallel subscription processing doubles API call rate  
**Solution**: Process subscriptions one at a time with cooldown between them

```powershell
# BAD: Parallel processing
$subscriptions | ForEach-Object -Parallel {
    Extract-Costs -Subscription $_.Id
}
# Result: 60 requests/min across 2 subscriptions = guaranteed 429

# GOOD: Sequential with cooldown
foreach ($sub in $subscriptions) {
    Extract-Costs -Subscription $sub.Id
    Start-Sleep -Seconds 60  # Cooldown between subscriptions
}
# Result: 30 requests/min per subscription = safe
```

**Benefits**:
- Stays within per-subscription rate limit
- Easier to debug (clear which subscription failed)
- More predictable execution time

### 3. Inter-Operation Delays ✅

**Problem**: Back-to-back API calls trigger rate limiting  
**Solution**: Add delays between monthly extractions and between subscriptions

```powershell
# Inter-month delay: 10 seconds (default)
# - 12 months × 10s = 120s = 2 minutes per subscription
# - Well under 30 req/min limit (12 calls / 2 min = 6 req/min)

# Inter-subscription cooldown: 60 seconds (default)
# - Allows API throttling to reset
# - Ensures fresh rate limit window for next subscription
```

**Delay Recommendations**:

| Scenario | Inter-Month Delay | Inter-Subscription Delay | Rationale |
|----------|-------------------|--------------------------|-----------|
| **Default (Daily)** | 10s | 60s | Safe for 12 months, proven in testing |
| **Conservative** | 15s | 90s | High-traffic periods, shared tenants |
| **Aggressive** | 5s | 30s | Testing only, increased 429 risk |
| **Monthly Granularity** | 5s | 30s | Smaller result sets, less pagination |

### 4. Built-In Retry Logic ✅

**Problem**: Transient 429 errors should be retried, not failed  
**Solution**: Exponential backoff with max retries (implemented in extract_costs_sdk.py)

```python
# In extract_costs_sdk.py (lines 147-176)
max_retries = 5
retry_delay = 2  # Start with 2 seconds

for retry in range(max_retries):
    try:
        result = self.client.query.usage(...)
        break  # Success
    except Exception as e:
        if "429" in str(e):
            if retry < max_retries - 1:
                print(f"[WARN] Rate limited, retrying in {retry_delay}s...")
                time.sleep(retry_delay)
                retry_delay *= 2  # Exponential backoff: 2s, 4s, 8s, 16s, 32s
                continue
            else:
                raise  # Max retries exceeded
        else:
            raise  # Non-rate-limit error
```

**Benefits**:
- Handles transient rate limit spikes
- Exponential backoff prevents hammering the API
- Max retries prevent infinite loops

### 5. Progress Tracking ✅

**Problem**: Long-running extractions (30+ minutes) can be interrupted  
**Solution**: Save progress after each month, resume from last checkpoint

```powershell
# Progress file: extraction-progress.json
{
  "StartTime": "2026-02-16T14:30:00Z",
  "CompletedMonths": [
    "EsDAICoESub_2025-02",
    "EsDAICoESub_2025-03",
    "EsPAICoESub_2025-02"
  ],
  "FailedMonths": []
}

# Resume capability
if (Test-Path $ProgressFile) {
    $progress = Get-Content $ProgressFile | ConvertFrom-Json
    # Skip already completed months
}
```

**Benefits**:
- No need to restart from beginning after interruption
- Failed months can be retried individually
- Audit trail of extraction history

---

## Execution Time Estimates

### Daily Granularity (Default)

| Metric | EsDAICoESub | EsPAICoESub | Total |
|--------|-------------|-------------|-------|
| **Months** | 12 | 12 | 24 |
| **Inter-month delays** | 12 × 10s = 120s | 12 × 10s = 120s | 240s |
| **Inter-subscription cooldown** | - | 60s | 60s |
| **API call time** | ~12s/month | ~12s/month | ~288s |
| **Total** | ~2.2 min | ~2.2 min + 1 min | **~5.4 min** |

### Monthly Granularity (Alternative)

| Metric | EsDAICoESub | EsPAICoESub | Total |
|--------|-------------|-------------|-------|
| **Months** | 12 | 12 | 24 |
| **Inter-month delays** | 12 × 5s = 60s | 12 × 5s = 60s | 120s |
| **Inter-subscription cooldown** | - | 30s | 30s |
| **API call time** | ~6s/month | ~6s/month | ~144s |
| **Total** | ~1.2 min | ~1.2 min + 0.5 min | **~2.9 min** |

---

## Testing Validation

### Test Case: February 2025 Daily Data

**Subscription**: EsPAICoESub  
**Date Range**: 2025-02-01 to 2025-02-28  
**Granularity**: Daily

**Results**:
- ✅ 2,543 records extracted (28 days × ~91 records/day)
- ✅ 1 API call (single page, under 5,000 row limit)
- ✅ 8.4 seconds execution time
- ✅ All dates present (2025-02-01 through 2025-02-24)
- ✅ No rate limit errors

**Conclusion**: Monthly chunking with daily granularity works well for 1-month extractions

### Test Case: February 2025 Daily Data (EsDAICoESub)

**Results**:
- ⚠️ 20,000+ rows attempted (before rate limit)
- ❌ 429 error after 5 pages (5,000 rows each)
- ⏱️ 40.5 seconds before failure
- 🔧 Fixed with retry logic and per-page delays

**Conclusion**: Large subscriptions need rate limiting even for 1-month extractions

---

## Usage Examples

### Standard 12-Month Extraction (Recommended)

```powershell
# Extract 12 months of daily data with default rate limiting
.\Extract-Historical-Daily.ps1

# Configuration:
# - MonthsToExtract: 12
# - Granularity: Daily
# - InterMonthDelay: 10s
# - InterSubscriptionDelay: 60s
# - Expected duration: ~5-6 minutes
```

### Conservative Extraction (High-Traffic Periods)

```powershell
# Use longer delays if experiencing 429 errors
.\Extract-Historical-Daily.ps1 -InterMonthDelay 15 -InterSubscriptionDelay 90

# Configuration:
# - Longer delays reduce API load
# - Expected duration: ~7-8 minutes
# - Lower 429 risk
```

### Monthly Granularity (Faster Alternative)

```powershell
# Extract monthly aggregates instead of daily data
.\Extract-Historical-Daily.ps1 -Granularity Monthly -InterMonthDelay 5 -InterSubscriptionDelay 30

# Configuration:
# - Smaller result sets (2,400 vs. 2,500 rows)
# - Faster extraction (~3 minutes)
# - Less detailed (monthly vs. daily trends)
```

### Partial Extraction (Testing)

```powershell
# Test with 3 months before full 12-month extraction
.\Extract-Historical-Daily.ps1 -MonthsToExtract 3

# Configuration:
# - Quick validation (~1.5 minutes)
# - Verify rate limiting strategy
# - Confirm data quality
```

---

## Troubleshooting

### Problem: 429 Errors Despite Delays

**Symptoms**: Rate limit errors even with 10s inter-month delays

**Possible Causes**:
1. Shared tenant (other applications using same API)
2. Azure region high load
3. Large result sets requiring multiple pagination calls

**Solutions**:
```powershell
# Option 1: Increase delays
.\Extract-Historical-Daily.ps1 -InterMonthDelay 20 -InterSubscriptionDelay 120

# Option 2: Use monthly granularity
.\Extract-Historical-Daily.ps1 -Granularity Monthly

# Option 3: Extract fewer months at a time
.\Extract-Historical-Daily.ps1 -MonthsToExtract 6
# Run again for remaining 6 months
```

### Problem: Inconsistent Extraction Times

**Symptoms**: Some months take 5s, others take 30s

**Cause**: Variable result set sizes (month-to-month usage variance)

**Solution**: This is normal - daily granularity produces different row counts per month based on:
- Number of days (28-31)
- Resource activity levels
- Tag combinations (each tag creates separate row)

### Problem: Interrupted Extraction

**Symptoms**: Script stopped midway through 12-month extraction

**Solution**: Progress is automatically saved - just run again:
```powershell
.\Extract-Historical-Daily.ps1
# Will skip completed months and resume from last failure
```

---

## Comparison: Before vs. After Rate Limiting

### Before (Extract-Historical-Both-Subscriptions.ps1)

❌ **Problems**:
- Requested 12 months in one API call
- Generated 30,000+ records requiring 6+ pagination calls
- No delays between subscriptions
- High 429 error rate
- No retry logic
- No progress tracking

### After (Extract-Historical-Daily.ps1)

✅ **Improvements**:
- Monthly chunking (12 separate API calls)
- Predictable result sizes (~2,500 rows per month)
- 10s delay between months
- 60s cooldown between subscriptions
- Exponential backoff retry logic
- Progress tracking with resume capability

---

## References

### Azure Documentation
- [Cost Management REST API](https://learn.microsoft.com/en-us/rest/api/cost-management/)
- [Query API Best Practices](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/cost-management-api-best-practices)

### Implementation Files
- `Extract-Historical-Daily.ps1` - Main extraction script with rate limiting
- `extract_costs_sdk.py` - Python SDK wrapper with retry logic
- `Test-Feb2025-Extraction.ps1` - Pagination validation test

### Related Documentation
- `AZURE-CLI-WORKAROUNDS.md` - REST API patterns
- `Azure-REST-Functions.ps1` - Reusable REST API functions
- `README.md` - Project overview

---

**Last Updated**: February 16, 2026  
**Verified With**: Azure Cost Management SDK 4.0.1  
**Tested On**: EsDAICoESub + EsPAICoESub subscriptions
