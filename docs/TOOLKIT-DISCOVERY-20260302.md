## FinOps Toolkit Discovery — Phase 3/4 Integration Roadmap

**Discovery Date**: March 2, 2026, 5:38 PM ET  
**Scope**: Deep analysis of Microsoft FinOps Toolkit components against project 14-az-finops current state  
**Audience**: Architecture, Phase 3/4 planning, technical debt assessment

---

## Component Assessment

### 1. FinOps Hubs [STATUS: GREEN - ALIGNED]

**Microsoft Docs**: https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/hubs/finops-hubs-overview

**Your Project Status**: Building today
- ADX cluster (marcofinopsadx) ✓
- ADF pipeline (ingest-costs-to-adx) ✓
- ADLS Gen2 containers (raw, archive, checkpoint) ✓
- Lifecycle policy (90d Cool, 180d Archive) ✓

**Toolkit Architecture**: Cost Management → Storage → ADF → ADX/Fabric + Power BI

**Key New Capability**: 5 Pre-built Power BI Reports
- Charge breakdown report (cost by resource/service)
- Cost summary (savings, trends, rate optimization)
- Recommendations dashboard (Azure Advisor integration)
- Governance report (subscription, resource, RBAC audit)
- Rate optimization (reservations, commitments, discounts)

**Integration Gap**: None – you're aligned. Toolkit reports can wire directly to your normalized_costs table.

**Phase 3 Action Item**:
```
Deliverable: Power BI report wired to normalized_costs table
Timeline: Week 7-8 (by Phase 3 end)
Effort: 2 story points
Tasks:
  1. Download PowerBI-kql.zip from toolkit latest release
  2. Wire 5 reports to your ADX connection string
  3. Map report fields → your ESDC dimensions (CanonicalEnvironment, SscBillingCode, etc.)
  4. Validate monthly cost totals match ADX smoke-test queries
  5. Deploy to Power BI service (if Foundry Prod uses it)
```

---

### 2. Azure Optimization Engine (AOE) [STATUS: YELLOW - MISSING]

**Microsoft Docs**: https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/optimization-engine/overview

**Your Project Status**: Not deployed
- You have manual "Advanced Capabilities Showcase" doc (12 analytics + 8 operational use cases)
- No automated weekly recommendations engine
- No unified workbook dashboard for anomalies, idle resources, etc.

**Toolkit Capability**: Production-grade recommendations framework
- Deployment: 5 min (PowerShell in Azure Cloud Shell)
- Schedule: Runs weekly, updates Log Analytics + SQL Server + Power BI
- Recommendations: 50+ pre-built rules (cost, HA, performance, security, OpsExc)
- Key overlap with your project: Idle resource detection, cost anomalies

**Detailed Recommendations (from toolkit)**:

**Cost (Your Domain)**:
- Augmented VM right-sizing (with guest OS perf metrics from Azure Monitor)
- Underutilized VMSS, premium disks, App Service plans, SQL DTU databases
- Orphaned disks and public IPs
- Load balancers without backend pools
- VMs deallocated long ago ("forgotten VMs")
- Storage accounts without retention policy
- App Service plans with no applications
- Stopped (not deallocated) VMs

**HA/Performance**:
- VM high availability audit (availability zones, managed disks, distribution)
- VMSS distribution analysis
- Virtual Machine Scale Sets constrained by compute
- SQL databases constrained by resources

**Security**:
- Service principal credentials without expiration
- NSG rules with orphaned NICs/public IPs
- Credentials expired or expiring soon
- Subscriptions/management groups near RBAC limits

**Workbooks Included** (10 total):
- Benefits simulation, Benefits usage, Block blob storage usage
- Costs growing, Identities and roles, Policy compliance
- Recommendations, Reservations potential, Reservations usage
- Resources inventory, Savings plans usage

**Phase 4 Integration** (Your Next Epic: Advanced Analytics):

```
Deliverable: AOE deployed and correlated with your ADX data
Timeline: Phase 4 weeks 1-3
Effort: 5 story points
Architecture:
  AOE Log Analytics → KQL query → ADX apim_usage table
  Correlate LS recommendations with your real spend
Cost: Included in existing Log Analytics + SQL Server pricing (no incremental)
Tasks:
  1. Deploy AOE via Cloud Shell (Deploy-AzureOptimizationEngine.ps1)
  2. Reuse your existing Log Analytics workspace (if available) or create new
  3. Wire AOE SQL Server database → Power BI Desktop
  4. Build custom report: AOE recommendations vs. normalized_costs
  5. Test on non-production resources first
  6. Set up Power Automate alert for P0 recommendations
```

**Risk**: Requires Log Analytics with VM performance metrics (Perf table). If you don't have VMs reporting metrics, VM right-sizing recommendations will be limited.

---

### 3. FinOps Workbooks [STATUS: YELLOW - PARTIAL]

**Microsoft Docs**: https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/workbooks/finops-workbooks-overview

**Your Project Status**: Docs only
- You have Advanced-Capabilities-Showcase.md (comprehensive written guide)
- No Azure Monitor workbooks deployed
- Manual KQL queries instead of pre-built workbooks

**Toolkit Capability**: 2 Pre-built Monitor Workbooks
- Optimization workbook (cost analysis, service breakdown, anomalies)
- Governance workbook (RBAC, subscriptions, resource audit)

**Deployment Options**:
1. ARM template deployment (requires Workbook Contributor role) — 2 min
2. Import JSON directly into Monitor (works with Reader-only access) — 5 min

**Phase 4 Action**:
```
Deliverable: Deploy toolkit workbooks alongside Advanced-Capabilities manual docs
Timeline: Phase 4 week 2
Effort: 1 story point
Tasks:
  1. Download finops-workbooks from toolkit latest release
  2. Deploy via ARM template OR import JSON to Monitor
  3. Wire to your ADLS Gen2 storage connection
  4. Test queries on normalized_costs table
  5. Socialize with ESDC stakeholders
```

---

### 4. FinOps Toolkit PowerShell Module [STATUS: YELLOW - NOT USING]

**Microsoft Docs**: https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/powershell/powershell-commands

**Your Project Status**: Using custom scripts
- Custom: `az-inventory-finops.ps1` (650 lines, tested)
- Custom: `migrate-costs-to-raw.ps1` (dry-run mode)
- Custom: assignment scripts, deployment helpers

**Toolkit Module** (`Install-Module FinOpsToolkit`):
- **Cost Management**: Get/New/Remove/Start Cost Exports
- **FinOps Hubs**: Deploy-FinOpsHub, Get-FinOpsHub, Initialize/Register/Remove
- **Open Data**: Get-FinOpsPricingUnit, Get-FinOpsRegion, Get-FinOpsResourceType, Get-FinOpsService

**Your Advantage**: Custom scripts give you exact control (e.g., RFC4180 escaping fix for ADF pipeline)

**Migration Path** (Optional):
- Keep custom scripts (good enough; no technical debt here)
- OR migrate to toolkit module for consistency with broader FinOps orgs

**Recommendation**: KEEP custom scripts. You've validated them; migration risk > benefit.

---

### 5. Bicep Registry Modules + Open Data [STATUS: YELLOW - PARTIAL]

**Microsoft Docs**:
- Modules: https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/bicep-registry/modules
- Open Data: https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/open-data

**Your Project Status**:
- Custom Bicep: adx-cluster.bicep, managed-identity.bicep, lifecycle-policy.json
- Custom PowerShell: assignment, deployment, execution
- 99.997% tag coverage on 460,609 rows (excellent)

**Toolkit Bicep Available**:
- **Scheduled actions module** — Cost Management email alerts on schedule or anomaly
  - Reference: `module <name> 'br/public:cost/scheduled-actions:<version>' { ... }`
  - Enables: Automated alerts to finance teams on cost spikes

**Toolkit Open Data** (5 Reference CSVs):
1. **PricingUnits.csv** (5K+ rows) — UnitOfMeasure → DistinctUnits + scaling factor
   - Example: "5 GB" → distinct_unit="GB", scaling_factor=5
   - Used in: Data normalization, pricing calculations

2. **Regions.csv** — Region name variants → Azure region IDs
   - Example: "ca central" → "canadacentral" → "Canada Central"
   - Used in: Normalizing Cost Management export values

3. **ResourceTypes.csv** — Resource type codes → display names + icons
   - Example: "microsoft.compute/virtualmachines" → "Virtual machine"
   - Used in: Reporting, governance, UI labels

4. **Services.csv** — ConsumedService + ResourceType → ServiceName (FOCUS-aligned)
   - Includes: Service category, cloud provider, IaaS/PaaS classification
   - Used in: Service-level cost attribution

5. **Dataset Examples** — Sample exports (Actual, Amortized, FOCUS 1.0)
   - Includes: EA sample data, FOCUS metadata, prices, reservations

**Your Use of Open Data**: Already have it implicitly (99.997% coverage = good normalization)

**Phase 4 Action**: FOCUS Alignment Validation

```
Deliverable: Validate your normalized_costs schema against FOCUS 1.0 spec
Timeline: Phase 4 week 3-4
Effort: 2 story points
Tasks:
  1. Download FOCUS examples + metadata from toolkit GitHub
  2. Map your normalized_costs columns → FOCUS spec columns
     Examples:
       Your: CanonicalEnvironment → FOCUS: (custom, not standard)
       Your: SscBillingCode → FOCUS: CostAllocationUnit (custom)
       Your: EffectiveCallerApp → FOCUS: (non-standard)
  3. Identify deviations from spec
  4. Document why (ESDC-specific: billing codes, environments, etc.)
  5. Risk assessment: Can other tools consume your ADX data?
  6. Consider: Add FOCUS-standard columns alongside ESDC columns
```

**Risk**: Your schema diverges from FOCUS (intentional for ESDC-specific needs). Long-term impact:
- Harder to integrate with Microsoft Fabric, Power BI templates
- Custom column mappings required for third-party tools
- Mitigation: Keep ESDC dimensions; ADD FOCUS-standard columns in parallel

---

## Integration Roadmap (Phase 3 → 4)

### Phase 3 (Weeks 5-9) — APIM + Toolkit Start

| Story | Effort | Toolkit Dependency | Your Benefit |
|-------|--------|-------------------|-------------|
| F14-05-002: Wire Power BI to ADX | 2 pts | FinOps Hubs (reports) | Real-time cost dashboard for stakeholders |
| F14-06-004: APIM Telemetry Pipeline | 8 pts | None (independent) | Cost attribution by API/caller (blocking Phase 3) |

### Phase 4 (Weeks 10-17) — Full Toolkit Integration

| Story | Effort | Toolkit Dependency | Your Benefit |
|-------|--------|-------------------|-------------|
| F14-05-003: Deploy AOE | 5 pts | Azure Optimization Engine | Weekly recommendations automation (replaces manual doc) |
| F14-05-004: FOCUS Validation | 2 pts | Open Data + Bicep | Schema alignment with Microsoft standard |
| F14-04-001: Finance Integration (SAP chargeback) | 13 pts | Scheduled Actions (optional) | Monthly invoicing automation |

---

## Decision Matrix

| Component | Recommendation | Rationale | Phase |
|-----------|---|---|---|
| **FinOps Hubs** | Align (continue) | You're already building it; pre-built reports accelerate | 3 |
| **AOE** | Deploy | Automates 12 manual analytics from your doc; worth 5 pts | 4 |
| **Workbooks** | Deploy | Complements your docs; Monitor-native UX | 4 |
| **PowerShell Module** | Keep custom | No benefit to migrate; your scripts are validated | Skip |
| **Bicep Modules** | Optional (Scheduled Actions later) | Good-to-have for automated alerting; not blocking | 4+ |
| **Open Data** | Validate (FOCUS alignment) | Your 99.997% coverage is good; add FOCUS columns for interop | 4 |

---

## Blockers & Dependencies

**None blocking Phase 3 completion**. APIM telemetry pipeline is your blocker (independent of toolkit).

**Phase 4 prerequisite**: Ensure you have Azure Log Analytics with VM performance metrics (Perf table) if you want full AOE VM right-sizing recommendations.

---

## Resource Links

| Resource | URL | Download |
|----------|-----|----------|
| FinOps Toolkit Releases | https://github.com/microsoft/finops-toolkit/releases/latest | finops-toolkit.zip |
| Power BI Reports | — | PowerBI-kql.zip |
| Optimization Engine Deployment | https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/optimization-engine/overview | Deploy-AzureOptimizationEngine.ps1 |
| Workbooks JSON | — | finops-workbooks-latest.json |
| Open Data CSVs | — | PricingUnits.csv, Regions.csv, etc. |
| FOCUS Spec | https://www.finops.org/focus/ | FOCUS 1.0 metadata |

---

## Next Steps

1. **Immediate (This Week)**: Download toolkit; review Power BI reports for Phase 3 wire-up
2. **Phase 3 Completion (Week 8-9)**: Wire toolkit Power BI → your ADX normalized_costs
3. **Phase 4 Planning (Week 9-10)**: Prioritize AOE deployment vs. other Phase 4 epics
4. **Phase 4 Setup (Weeks 13-14)**: Deploy AOE into preproduction environment
5. **Phase 4 Validation (Weeks 15-17)**: FOCUS schema alignment + correlation testing
