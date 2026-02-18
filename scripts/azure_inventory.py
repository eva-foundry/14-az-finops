#!/usr/bin/env python3
"""
Azure Resource Inventory using Azure SDK for Python
Replaces Test-ServicesCapabilities.ps1 PowerShell approach

Author: Marco Framework
Date: 2026-01-29
"""

import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List
import json

try:
    import pandas as pd
    from azure.mgmt.resource import ResourceManagementClient
    from azure.identity import DefaultAzureCredential, AzureCliCredential
except ImportError as e:
    print(f"[ERROR] Missing required package: {e}")
    print("[INFO] Install with: pip install -r requirements.txt")
    sys.exit(1)


class AzureInventoryCollector:
    """Collect Azure resource inventory with tag compliance"""
    
    def __init__(self, subscription_id: str, subscription_name: str = None):
        """
        Initialize inventory collector
        
        Args:
            subscription_id: Azure subscription GUID
            subscription_name: Friendly name for reports
        """
        self.subscription_id = subscription_id
        self.subscription_name = subscription_name or subscription_id
        
        # Try Azure CLI credential first (local dev)
        try:
            self.credential = AzureCliCredential()
            print(f"[INFO] Using Azure CLI authentication")
        except Exception:
            print(f"[INFO] Azure CLI not available, using DefaultAzureCredential")
            self.credential = DefaultAzureCredential()
        
        self.client = ResourceManagementClient(self.credential, subscription_id)
        print(f"[PASS] Connected to subscription: {self.subscription_name}")
    
    def collect_resources(self) -> pd.DataFrame:
        """
        Collect all resources with tags and metadata
        
        Replaces Test-ServicesCapabilities.ps1 resource discovery
        
        Returns:
            DataFrame with resource inventory
        """
        print(f"[INFO] Collecting resources from {self.subscription_name}...")
        
        resources = []
        
        try:
            # List all resources in subscription
            for resource in self.client.resources.list():
                # Extract resource group from ID
                rg_name = self._extract_resource_group(resource.id)
                
                # Get tags
                tags = resource.tags or {}
                
                # Build resource record
                resource_record = {
                    'subscription_id': self.subscription_id,
                    'subscription_name': self.subscription_name,
                    'resource_id': resource.id,
                    'name': resource.name,
                    'type': resource.type,
                    'location': resource.location,
                    'resource_group': rg_name,
                    'sku': resource.sku.name if resource.sku else None,
                    'kind': resource.kind if hasattr(resource, 'kind') else None,
                    # Governance tags
                    'tag_environment': tags.get('environment'),
                    'tag_team': tags.get('team'),
                    'tag_client': tags.get('client'),
                    'tag_manager': tags.get('manager'),
                    'tag_projectname': tags.get('projectname'),
                    'tag_fin_costcenter': tags.get('fin_costcenter'),
                    'tag_ops_productowner': tags.get('ops_productowner'),
                    'tag_shared_cost': tags.get('shared_cost'),
                    # Tag compliance
                    'has_environment_tag': 'environment' in tags,
                    'has_team_tag': 'team' in tags,
                    'has_client_tag': 'client' in tags,
                    'all_tags_json': json.dumps(tags)
                }
                
                resources.append(resource_record)
            
            df = pd.DataFrame(resources)
            
            # Calculate tag compliance score
            if len(df) > 0:
                required_tags = ['has_environment_tag', 'has_team_tag', 'has_client_tag']
                df['tag_compliance_score'] = df[required_tags].sum(axis=1) / len(required_tags)
            
            print(f"[PASS] Collected {len(df):,} resources")
            return df
            
        except Exception as e:
            print(f"[ERROR] Resource collection failed: {e}")
            raise
    
    def _extract_resource_group(self, resource_id: str) -> str:
        """Extract resource group name from resource ID"""
        parts = resource_id.split('/')
        try:
            rg_index = parts.index('resourceGroups') + 1
            return parts[rg_index]
        except (ValueError, IndexError):
            return None
    
    def analyze_tag_compliance(self, df: pd.DataFrame) -> Dict:
        """
        Analyze tag compliance across resources
        
        Returns:
            Dict with compliance statistics
        """
        print(f"\n[INFO] Analyzing tag compliance...")
        
        total = len(df)
        if total == 0:
            return {'total_resources': 0}
        
        # Count resources with each tag
        with_environment = df['has_environment_tag'].sum()
        with_team = df['has_team_tag'].sum()
        with_client = df['has_client_tag'].sum()
        
        # Calculate compliance rate
        fully_compliant = df[
            df['has_environment_tag'] & 
            df['has_team_tag'] & 
            df['has_client_tag']
        ]
        
        stats = {
            'total_resources': total,
            'environment_tag_count': int(with_environment),
            'environment_tag_pct': (with_environment / total) * 100,
            'team_tag_count': int(with_team),
            'team_tag_pct': (with_team / total) * 100,
            'client_tag_count': int(with_client),
            'client_tag_pct': (with_client / total) * 100,
            'fully_compliant_count': len(fully_compliant),
            'fully_compliant_pct': (len(fully_compliant) / total) * 100,
            'avg_compliance_score': df['tag_compliance_score'].mean() * 100
        }
        
        # Display results
        print(f"\n[INFO] Tag Compliance Report:")
        print(f"  Total Resources: {total:,}")
        print(f"  Environment Tag: {stats['environment_tag_pct']:.1f}% ({with_environment:,})")
        print(f"  Team Tag: {stats['team_tag_pct']:.1f}% ({with_team:,})")
        print(f"  Client Tag: {stats['client_tag_pct']:.1f}% ({with_client:,})")
        print(f"  Fully Compliant: {stats['fully_compliant_pct']:.1f}% ({len(fully_compliant):,})")
        print(f"  Avg Compliance Score: {stats['avg_compliance_score']:.1f}%")
        
        return stats
    
    def identify_non_compliant_resources(self, df: pd.DataFrame) -> pd.DataFrame:
        """Find resources missing required tags"""
        
        non_compliant = df[
            ~(df['has_environment_tag'] & 
              df['has_team_tag'] & 
              df['has_client_tag'])
        ].copy()
        
        # Add missing tags info
        non_compliant['missing_tags'] = non_compliant.apply(
            lambda row: ', '.join([
                tag.replace('has_', '').replace('_tag', '')
                for tag in ['has_environment_tag', 'has_team_tag', 'has_client_tag']
                if not row[tag]
            ]),
            axis=1
        )
        
        return non_compliant[['name', 'type', 'resource_group', 'missing_tags']]
    
    def export_to_csv(self, df: pd.DataFrame, output_path: str):
        """Export DataFrame to CSV"""
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        df.to_csv(output_file, index=False, encoding='utf-8')
        print(f"[PASS] Exported to {output_path}")
    
    def export_to_json(self, df: pd.DataFrame, output_path: str):
        """Export DataFrame to JSON"""
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        df.to_json(output_file, orient='records', indent=2)
        print(f"[PASS] Exported to {output_path}")


def main():
    """Main execution"""
    
    print("\n" + "="*60)
    print("Azure Resource Inventory - Azure SDK Implementation")
    print("Replaces Test-ServicesCapabilities.ps1")
    print("="*60 + "\n")
    
    # ESDC subscriptions
    subscriptions = {
        "EsDAICoESub": "d2d4e571-e0f2-4f6c-901a-f88f7669bcba",
        "EsPAICoESub": "802d84ab-3189-4221-8453-fcc30c8dc8ea"
    }
    
    # Collect inventory from all subscriptions
    all_resources = []
    all_stats = {}
    
    for name, sub_id in subscriptions.items():
        print(f"\n{'='*60}")
        print(f"Processing: {name}")
        print(f"{'='*60}")
        
        try:
            # Initialize collector
            collector = AzureInventoryCollector(sub_id, name)
            
            # Collect resources
            df = collector.collect_resources()
            
            # Analyze compliance
            stats = collector.analyze_tag_compliance(df)
            all_stats[name] = stats
            
            # Export individual subscription
            csv_path = f"portal-exports/inventory/{name}_resources.csv"
            json_path = f"portal-exports/inventory/{name}_resources.json"
            
            collector.export_to_csv(df, csv_path)
            collector.export_to_json(df, json_path)
            
            # Export non-compliant resources
            non_compliant = collector.identify_non_compliant_resources(df)
            if len(non_compliant) > 0:
                nc_path = f"portal-exports/inventory/{name}_non_compliant.csv"
                collector.export_to_csv(non_compliant, nc_path)
                print(f"[WARN] {len(non_compliant):,} non-compliant resources exported to {nc_path}")
            
            # Add to combined dataset
            all_resources.append(df)
            
        except Exception as e:
            print(f"[ERROR] Failed to process {name}: {e}")
            continue
    
    # Combine all subscriptions
    if all_resources:
        print(f"\n{'='*60}")
        print("Combined Inventory Summary")
        print(f"{'='*60}")
        
        combined_df = pd.concat(all_resources, ignore_index=True)
        
        # Export combined
        combined_csv = "portal-exports/inventory/all_subscriptions_resources.csv"
        combined_json = "portal-exports/inventory/all_subscriptions_resources.json"
        
        combined_df.to_csv(combined_csv, index=False, encoding='utf-8')
        combined_df.to_json(combined_json, orient='records', indent=2)
        
        print(f"[INFO] Total Resources: {len(combined_df):,}")
        print(f"[INFO] CSV: {combined_csv}")
        print(f"[INFO] JSON: {combined_json}")
        
        # Overall compliance
        total_resources = sum(s['total_resources'] for s in all_stats.values())
        total_compliant = sum(s['fully_compliant_count'] for s in all_stats.values())
        overall_compliance = (total_compliant / total_resources * 100) if total_resources > 0 else 0
        
        print(f"\n[INFO] Overall Tag Compliance: {overall_compliance:.1f}%")
        for sub_name, stats in all_stats.items():
            print(f"  {sub_name}: {stats['fully_compliant_pct']:.1f}%")
    
    print(f"\n{'='*60}")
    print("Inventory Collection Complete")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
