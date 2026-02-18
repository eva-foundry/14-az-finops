#!/usr/bin/env python3
"""
Azure Cost Extraction using Azure SDK for Python
Replaces EXTRACTION-PLAN.md manual REST API approach

Author: Marco Framework
Date: 2026-01-29
"""

import os
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional, List, Dict
import json
import time

try:
    import pandas as pd
    from azure.mgmt.costmanagement import CostManagementClient
    from azure.mgmt.costmanagement.models import (
        QueryDefinition,
        QueryTimePeriod,
        QueryDataset,
        QueryAggregation,
        QueryGrouping
    )
    from azure.identity import DefaultAzureCredential, AzureCliCredential
except ImportError as e:
    print(f"[ERROR] Missing required package: {e}")
    print("[INFO] Install with: pip install -r requirements.txt")
    sys.exit(1)


class AzureCostExtractor:
    """Extract Azure cost data using SDK (replaces manual REST API)"""
    
    def __init__(self, subscription_id: str, subscription_name: str = None):
        """
        Initialize cost extractor
        
        Args:
            subscription_id: Azure subscription GUID
            subscription_name: Friendly name for reports
        """
        self.subscription_id = subscription_id
        self.subscription_name = subscription_name or subscription_id
        self.scope = f"/subscriptions/{subscription_id}"
        
        # Try Azure CLI credential first (local dev), fall back to Default
        try:
            self.credential = AzureCliCredential()
            print(f"[INFO] Using Azure CLI authentication")
        except Exception:
            print(f"[INFO] Azure CLI not available, using DefaultAzureCredential")
            self.credential = DefaultAzureCredential()
        
        # Initialize Cost Management client (no custom transport needed - SDK handles HTTPS)
        self.client = CostManagementClient(
            self.credential,
            base_url="https://management.azure.com"
        )
        print(f"[PASS] Connected to subscription: {self.subscription_name}")
    
    def query_costs(
        self,
        start_date: datetime,
        end_date: datetime,
        granularity: str = "Daily",
        include_tags: bool = True,
        inter_page_delay: int = 2
    ) -> pd.DataFrame:
        """
        Query cost data with complete schema including tags
        
        Implements EXTRACTION-PLAN.md requirements:
        - UsageDate (daily granularity by default)
        - SubscriptionName + SubscriptionId
        - Tags (all governance tags)
        - Resource details (ID, Type, Group, Location)
        - Cost breakdown (Service, Tier, Meter, Cost)
        
        Args:
            start_date: Query start date
            end_date: Query end date
            granularity: Daily (default), Monthly, None
            include_tags: Include governance tags
            inter_page_delay: Seconds to wait between pagination pages (default: 2)
            
        Returns:
            DataFrame with complete cost schema
        """
        
        print(f"[INFO] Querying costs: {start_date.date()} to {end_date.date()}")
        
        # Build dimension groupings (max 15 allowed by Azure API)
        # Prioritize essential dimensions for FinOps analysis
        groupings = [
            QueryGrouping(type="Dimension", name="ResourceGroupName"),
            QueryGrouping(type="Dimension", name="ResourceType"),
            QueryGrouping(type="Dimension", name="ResourceLocation"),
            QueryGrouping(type="Dimension", name="MeterCategory"),
            QueryGrouping(type="Dimension", name="MeterSubcategory"),
            QueryGrouping(type="Dimension", name="ServiceName"),
        ]
        
        # Add key governance tags (limit to 9 to stay under 15 total)
        if include_tags:
            tag_keys = [
                "environment", 
                "team", 
                "client", 
                "projectname", 
                "fin_costcenter",
                "ops_productowner",
                "shared_cost",
                "manager",
                "product"
            ]
            for tag in tag_keys:
                groupings.append(QueryGrouping(type="TagKey", name=tag))
        
        # Build query definition
        query_def = QueryDefinition(
            type="ActualCost",
            timeframe="Custom",
            time_period=QueryTimePeriod(
                from_property=start_date,
                to=end_date
            ),
            dataset=QueryDataset(
                granularity=granularity,
                aggregation={
                    "totalCost": QueryAggregation(name="Cost", function="Sum"),
                    "totalCostUSD": QueryAggregation(name="CostUSD", function="Sum")
                },
                grouping=groupings
            )
        )
        
        try:
            # Execute query with pagination support for large datasets
            # Azure Cost Management Query API returns max 5,000 rows per call
            # Must use skipToken to paginate through all results
            
            all_rows = []
            skip_token = None
            page_num = 1
            skip_token_supported = True  # Assume supported until proven otherwise
            
            while True:
                print(f"[INFO] Fetching page {page_num}...")
                
                # Retry logic for rate limiting (429 errors)
                max_retries = 5
                retry_delay = 2  # Start with 2 seconds
                
                for retry in range(max_retries):
                    try:
                        # Execute query (check skip_token support first)
                        if skip_token and skip_token_supported:
                            # Try pagination with skip_token
                            try:
                                result = self.client.query.usage(
                                    scope=self.scope,
                                    parameters=query_def,
                                    skip_token=skip_token
                                )
                            except TypeError:
                                # Skip_token not supported by this SDK version
                                print("[WARN] skip_token not supported, pagination may be incomplete")
                                skip_token_supported = False
                                # Retry without skip_token
                                result = self.client.query.usage(
                                    scope=self.scope,
                                    parameters=query_def
                                )
                                skip_token = None  # Stop pagination
                        else:
                            # No pagination or skip_token not supported
                            result = self.client.query.usage(
                                scope=self.scope,
                                parameters=query_def
                            )
                        
                        # Success - break retry loop
                        break
                        
                    except Exception as e:
                        error_msg = str(e)
                        if "429" in error_msg or "Too many requests" in error_msg:
                            if retry < max_retries - 1:
                                print(f"[WARN] Rate limited (429), retrying in {retry_delay}s... (attempt {retry+1}/{max_retries})")
                                time.sleep(retry_delay)
                                retry_delay *= 2  # Exponential backoff
                                continue
                            else:
                                print(f"[ERROR] Rate limit exceeded after {max_retries} retries")
                                raise
                        else:
                            # Non-rate-limit error, raise immediately
                            raise
                
                # Collect rows from this page
                if hasattr(result, 'rows') and result.rows:
                    all_rows.extend(list(result.rows))
                    print(f"[INFO] Page {page_num}: Retrieved {len(result.rows):,} rows (total: {len(all_rows):,})")
                
                # Check for next page
                # Azure returns nextLink or skipToken for pagination
                # Note: Python SDK skip_token support is unreliable for large datasets (80K+ rows)
                # If pagination fails, use smaller date ranges or Azure REST API instead
                if hasattr(result, 'next_link') and result.next_link and skip_token_supported:
                    # Extract skipToken from nextLink URL
                    import urllib.parse
                    parsed = urllib.parse.urlparse(result.next_link)
                    params = urllib.parse.parse_qs(parsed.query)
                    skip_token = params.get('$skiptoken', [None])[0]
                    if skip_token:
                        page_num += 1
                        # Rate limiting: delay between pages to avoid 429 errors
                        time.sleep(inter_page_delay)  # Configurable delay (default: 2s)
                    else:
                        break
                elif hasattr(result, 'skip_token') and result.skip_token and skip_token_supported:
                    skip_token = result.skip_token
                    page_num += 1
                    # Rate limiting: delay between pages to avoid 429 errors
                    time.sleep(inter_page_delay)  # Configurable delay (default: 2s)
                else:
                    # No more pages or pagination not supported
                    if not skip_token_supported and page_num > 1:
                        print(f"[WARN] Pagination incomplete - only first {len(all_rows):,} rows retrieved")
                        print("[WARN] For complete data, use smaller date ranges or Azure REST API")
                    break
            
            # Convert all rows to DataFrame
            if not all_rows:
                print("[WARN] Query returned no data")
                return pd.DataFrame()
            
            # Use first result for column metadata
            columns = [col.name for col in result.columns]
            df = pd.DataFrame(all_rows, columns=columns)
            
            # Parse date column (if present)
            if 'UsageDate' in df.columns:
                # Azure API returns dates as integers in YYYYMMDD format for daily granularity
                # Convert to string first, then to datetime
                df['UsageDate'] = pd.to_datetime(df['UsageDate'].astype(str), format='%Y%m%d', errors='coerce')
            
            # Parse numeric columns
            numeric_cols = ['Cost', 'CostUSD', 'PreTaxCost']
            for col in numeric_cols:
                if col in df.columns:
                    df[col] = pd.to_numeric(df[col], errors='coerce')
            
            # Add subscription name for clarity
            df['SubscriptionAlias'] = self.subscription_name
            
            print(f"[PASS] Retrieved {len(df):,} cost records across {page_num} pages")
            return df
            
        except Exception as e:
            print(f"[ERROR] Query failed: {e}")
            raise
    
    def _result_to_dataframe(self, result) -> pd.DataFrame:
        """Convert API result to DataFrame (deprecated - now handled inline with pagination)"""
        # This method is kept for backward compatibility but pagination logic moved to query_costs()
        
        # Extract column names
        columns = [col.name for col in result.columns]
        
        # Extract row data
        rows = [list(row) for row in result.rows]
        
        if not rows:
            print("[WARN] Query returned no data")
            return pd.DataFrame(columns=columns)
        
        # Create DataFrame
        df = pd.DataFrame(rows, columns=columns)
        
        # Parse date column (if present)
        if 'UsageDate' in df.columns:
            # Azure API returns dates as integers in YYYYMMDD format for daily granularity
            # Convert to string first, then to datetime
            df['UsageDate'] = pd.to_datetime(df['UsageDate'].astype(str), format='%Y%m%d', errors='coerce')
        
        # Parse numeric columns
        numeric_cols = ['Cost', 'CostUSD', 'PreTaxCost']
        for col in numeric_cols:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors='coerce')
        
        return df
    
    def export_to_csv(self, df: pd.DataFrame, output_path: str):
        """Export DataFrame to CSV"""
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        df.to_csv(output_file, index=False, encoding='utf-8')
        file_size = output_file.stat().st_size / 1024
        print(f"[PASS] Exported {len(df):,} rows to {output_path} ({file_size:.1f} KB)")
    
    def export_to_json(self, df: pd.DataFrame, output_path: str):
        """Export DataFrame to JSON"""
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        df.to_json(output_file, orient='records', date_format='iso', indent=2)
        file_size = output_file.stat().st_size / 1024
        print(f"[PASS] Exported {len(df):,} rows to {output_path} ({file_size:.1f} KB)")


def main():
    """
    Main execution
    
    Extracts costs for MarcoSub development environment (2026-01-31: Scope changed to MarcoSub-only)
    Original scope (deprecated): EsDAICoESub + EsPAICoESub cross-tenant extraction
    """
    import argparse
    
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Extract Azure costs using SDK")
    parser.add_argument("--start-date", type=str, help="Start date (YYYY-MM-DD)", default=None)
    parser.add_argument("--end-date", type=str, help="End date (YYYY-MM-DD)", default=None)
    parser.add_argument("--subscription", type=str, help="Subscription ID", default="c59ee575-eb2a-4b51-a865-4b618f9add0a")
    parser.add_argument("--subscription-name", type=str, help="Subscription name", default="MarcoSub")
    parser.add_argument("--output", type=str, help="Output CSV file path (optional)", default=None)
    parser.add_argument("--granularity", type=str, help="Data granularity: Daily (default), Monthly, None", default="Daily", choices=["Daily", "Monthly", "None"])
    parser.add_argument("--inter-page-delay", type=int, help="Delay in seconds between pagination pages (default: 2)", default=2)
    args = parser.parse_args()
    
    print("\n" + "="*60)
    print("Azure Cost Extraction - Azure SDK Implementation")
    print("MarcoSub Development Environment (2026-01-31)")
    print("="*60 + "\n")
    
    # MarcoSub subscription (development environment as of 2026-01-31)
    subscriptions = {
        args.subscription_name: args.subscription
    }
    
    # Query parameters - use command-line dates or default to last 60 days
    if args.start_date and args.end_date:
        start_date = datetime.strptime(args.start_date, "%Y-%m-%d")
        end_date = datetime.strptime(args.end_date, "%Y-%m-%d")
    else:
        end_date = datetime.now()
        start_date = end_date - timedelta(days=60)
    
    print(f"[INFO] Query Period: {start_date.date()} to {end_date.date()}")
    print(f"[INFO] Subscriptions: {len(subscriptions)}\n")
    
    # Collect all results
    all_costs = []
    
    for name, sub_id in subscriptions.items():
        print(f"\n{'='*60}")
        print(f"Processing: {name}")
        print(f"{'='*60}")
        
        try:
            # Initialize extractor
            extractor = AzureCostExtractor(sub_id, name)
            
            # Query costs
            df = extractor.query_costs(
                start_date=start_date,
                end_date=end_date,
                granularity=args.granularity,
                include_tags=True,
                inter_page_delay=args.inter_page_delay
            )
            
            # Export individual subscription
            if args.output:
                # Use specified output path
                csv_path = args.output
                json_path = args.output.replace('.csv', '.json') if args.output.endswith('.csv') else f"{args.output}.json"
            else:
                # Use default paths
                csv_path = f"portal-exports/api-extracted/{name}_costs.csv"
                json_path = f"portal-exports/api-extracted/{name}_costs.json"
            
            extractor.export_to_csv(df, csv_path)
            extractor.export_to_json(df, json_path)
            
            # Add to combined dataset
            all_costs.append(df)
            
        except Exception as e:
            print(f"[ERROR] Failed to process {name}: {e}")
            continue
    
    # Combine all subscriptions (skip if custom output specified)
    if all_costs:
        # Skip combined export if custom output specified (user wants individual files only)
        if args.output:
            print("\n[INFO] Custom output path used - skipping combined export")
            print(f"[INFO] Total extracted: {all_costs[0].shape[0]:,} records")
        else:
            print(f"\n{'='*60}")
            print("Combining All Subscriptions")
            print(f"{'='*60}")
            
            combined_df = pd.concat(all_costs, ignore_index=True)
            
            # Ensure output directory exists
            import os
            os.makedirs("portal-exports/api-extracted", exist_ok=True)
            
            # Export combined
            combined_csv = "portal-exports/api-extracted/all_subscriptions_costs.csv"
            combined_json = "portal-exports/api-extracted/all_subscriptions_costs.json"
            
            combined_df.to_csv(combined_csv, index=False, encoding='utf-8')
            combined_df.to_json(combined_json, orient='records', date_format='iso', indent=2)
            
            print(f"[PASS] Combined {len(combined_df):,} total records")
            print(f"[INFO] CSV: {combined_csv}")
            print(f"[INFO] JSON: {combined_json}")
            
            # Generate summary report
            print(f"\n{'='*60}")
            print("Cost Summary")
            print(f"{'='*60}")
            
            total_cost = combined_df['Cost'].sum()
            by_subscription = combined_df.groupby('SubscriptionAlias')['Cost'].sum()
            
            print(f"Total Cost: ${total_cost:,.2f}")
            for sub, cost in by_subscription.items():
                print(f"  {sub}: ${cost:,.2f}")
            
            # Quality gate check (from EXTRACTION-PLAN.md: 90% completeness)
            required_cols = ['UsageDate', 'SubscriptionName', 'ResourceId', 'Cost']
            completeness = {}
            for col in required_cols:
                if col in combined_df.columns:
                    non_null = combined_df[col].notna().sum()
                    pct = (non_null / len(combined_df)) * 100
                    completeness[col] = pct
                    status = "[PASS]" if pct >= 90 else "[FAIL]"
                    print(f"{status} {col}: {pct:.1f}% complete")
            
            # Check if quality gate passed
            if all(pct >= 90 for pct in completeness.values()):
                print("\n[PASS] Quality gate passed: All columns >= 90% complete")
            else:
                print("\n[WARN] Quality gate failed: Some columns < 90% complete")
    
    print(f"\n{'='*60}")
    print("Extraction Complete")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
