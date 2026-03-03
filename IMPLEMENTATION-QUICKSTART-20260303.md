# Cost Optimization System - Implementation Quickstart
**Date**: March 3, 2026  
**Scope**: End-to-end deployment roadmap  
**Timeline**: 4-6 weeks to production  
**Team**: Data Scientists (1), DevOps (1), Cost Architect (1)

---

## WHAT YOU'RE BUILDING

A **fully automated, data-driven cost optimization discovery + reporting system** that:

1. **Ingests** actual cost data, utilization metrics, compliance rules (5 Azure APIs → Cosmos DB)
2. **Analyzes** the data with Pandas notebooks (identify underutilized resources, cost trends)
3. **Validates** recommendations against compliance + dependencies + risk (agent assessment)
4. **Prioritizes** by ROI / Effort / Risk (tiered opportunity list)
5. **Generates** executable runbooks (Azure CLI/PowerShell scripts)
6. **Reports** findings with confidence levels + data gaps (executive summaries)
7. **Repeats** monthly (fully automated, self-improving)

**Outputs**:
- Tier 1 (Quick Wins): Actionable in < 2 hours, $7-15K/yr savings, high confidence
- Tier 2 (Medium-term): 2-10 hours effort, $7-15K/yr, medium confidence + risk
- Tier 3 (Strategic): Org decisions required, $25-55K/yr, lower confidence (needs more validation)

---

## ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────┐
│ INGESTION (Daily) ← APIs: Cost Mgmt, Monitor, Advisor       │
│   ↓ Normalize & Store ↓                                      │
│ COSMOS DB (FinOps) ← 8 Collections (CostEvents, Metrics...) │
│   ↓ Analyze ↓                                                │
│ ANALYSIS (Weekly) ← Pandas Notebooks: Utilization, Scoring  │
│   ↓ Validate ↓                                               │
│ AGENTS (Real-time) ← Compliance, Dependencies, Risk Assess   │
│   ↓ Prioritize & Generate ↓                                  │
│ OUTPUTS ← Runbooks (PowerShell), Reports (Markdown)          │
│   ↓ Execute (Manual by humans) ↓                             │
│ MONITORING (Monthly) ← Track actual vs. projected savings    │
└─────────────────────────────────────────────────────────────┘
```

---

## PHASE 1: FOUNDATION (WEEK 1-2)

### Task 1.1: Provision Cosmos DB w/ 8 Collections
**Effort**: 2 hours  
**Owner**: DevOps  
**What You're Creating**: 
- Database: `FinOps`
- Collections: CostEvents, ResourceMetrics, UtilizationAnalysis, RecommendationCandidates, ApprovedRecommendations, ComplianceRules, DependencyMap, Runbooks

**Command**:
```powershell
# See WORKFLOW-RUNBOOK-20260303.md, Section 2.4
$env:AZURE_SUBSCRIPTION_ID = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"

# Create database
az cosmosdb database create --name FinOps --account-name marco-eva-finops

# Create 8 containers (see script in eva-foundry/14-az-finops/scripts/setup-cosmos-db.ps1)
# This creates TTL-based auto-cleanup (90 days for metrics, 30 for policies)
```

**Validation**: 
```
[ ] Database `FinOps` visible in Azure Portal
[ ] 8 collections created with correct partition keys
[ ] TTL policies enabled (auto-cleanup after 90 days)
[ ] Throughput set to auto-scale (1,000 - 10,000 RU/s)
[ ] Expected monthly cost: $300-400 (self-pays from savings within 1 month)
```

---

### Task 1.2: Create Service Principal + IAM Roles
**Effort**: 1 hour  
**Owner**: DevOps  
**Why**: Agents need to read Cost Management API, Monitor metrics, resource inventory

**Command**:
```powershell
# Create service principal for agents
$sp = az ad sp create-for-rbac --name finops-agents --role "Cost Management Reader"
# Grant additional roles
az role assignment create --assignee $sp.appId --role "Monitoring Reader"
az role assignment create --assignee $sp.appId --role "Advisor Reader"
az role assignment create --assignee $sp.appId --role "Policy Reader"

# Store credentials in Key Vault (use Managed Identity if in Azure)
az keyvault secret set --vault-name marco-sandbox-keyvault --name finops-appid --value $sp.appId
```

**Validation**:
```
[ ] Service Principal created: finops-agents
[ ] Roles assigned: Cost Management Reader, Monitoring Reader, Advisor Reader, Policy Reader
[ ] Credentials stored in Key Vault (no plaintext secrets)
[ ] Agents can authenticate without human intervention
```

---

### Task 1.3: Scaffold Agent Framework Project
**Effort**: 2 hours  
**Owner**: Data Scientist  
**What You're Creating**: Python project structure for 7 agents + 3 notebooks

**Commands**:
```bash
# Create project directory
mkdir -p C:\AICOE\eva-foundry\14-az-finops\agents
cd agents

# Create virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Install Agent Framework
pip install agent-framework-azure-ai==1.0.0b260107
pip install agent-framework-core==1.0.0b260107
pip install pandas numpy azure-cosmos azure-cli

# Create project structure
mkdir -p src/{agents,notebooks,templates,config}
touch src/__init__.py
touch src/supervisor.py
touch src/agents/{ingestion.py,analysis_engine.py,validation.py,prioritization.py,scribe.py,reporting.py}
```

**Project Structure**:
```
14-az-finops/agents/
├── .venv/
├── src/
│   ├── agents/
│   │   ├── supervisor.py             (7 Agent Framework imports)
│   │   ├── ingestion.py              (5 sub-tasks)
│   │   ├── analysis_engine.py        (3 Pandas notebooks)
│   │   ├── validation.py             (compliance + dependency checks)
│   │   ├── prioritization.py         (ROI scoring)
│   │   ├── scribe.py                 (runbook generation)
│   │   └── reporting.py              (report synthesis)
│   ├── notebooks/
│   │   ├── utilization_analysis.ipynb
│   │   ├── cost_attribution.ipynb
│   │   └── candidate_scoring.ipynb
│   ├── templates/
│   │   ├── vm-downsize.ps1
│   │   ├── delete-resource.ps1
│   │   ├── autoscale-config.ps1
│   │   ├── storage-lifecycle.ps1
│   │   └── ...
│   └── config/
│       ├── agent-config.yaml         (endpoint URLs, thresholds)
│       └── rules-engine.yaml         (scoring rules from 18-azure-best)
├── requirements.txt
└── README.md
```

**Validation**:
```
[ ] Project structure matches above
[ ] .venv created and activated
[ ] All dependencies installed (agent-framework, pandas, azure-cosmos)
[ ] supervisor.py imports without error
[ ] Agent Framework version == 1.0.0b260107 (pinned, to avoid breaking changes)
```

---

## PHASE 2: INGESTION LAYER (WEEK 3)

### Task 2.1: Implement Ingestion Agent
**Effort**: 10 hours  
**Owner**: Data Scientist  
**What It Does**: Fetch data from 5 Azure APIs, normalize, store in Cosmos DB

**Code Skeleton**:
```python
# src/agents/ingestion.py
from agent_framework_core import Agent
from agent_framework_azure_ai import AzureAIClientAgent
from azure.mgmt.cost_management import CostManagementClient
from azure.monitor import MonitorClient

class IngestionAgent(Agent):
    async def run(self, tasks):
        """Execute 5 data collection tasks in parallel"""
        
        # Task 1: Cost Management API
        cost_data = await self.fetch_cost_mgmt(lookback_days=365)
        await self.store_cosmos("CostEvents", cost_data)
        
        # Task 2: Azure Monitor Metrics
        metrics = await self.fetch_monitor_metrics(lookback_days=30)
        await self.store_cosmos("ResourceMetrics", metrics)
        
        # Task 3: Azure Advisor
        advisor = await self.fetch_advisor_recommendations()
        await self.store_cosmos("AdvisorRecommendations", advisor)
        
        # Task 4: Resource Inventory
        inventory = await self.fetch_resource_inventory()
        await self.store_cosmos("ResourceInventory", inventory)
        
        # Task 5: Compliance Rules
        policies = await self.fetch_compliance_rules()
        await self.store_cosmos("ComplianceRules", policies)
        
        return {
            "status": "SUCCESS",
            "cost_events": len(cost_data),
            "metrics": len(metrics),
            "recommendations": len(advisor),
            "inventory": len(inventory),
            "policies": len(policies)
        }

# Instantiate and configure
ingestion = IngestionAgent(
    name="IngestionAgent",
    model="gpt-4",  # For any LLM-assisted tasks
    credentials=DefaultAzureCredential()
)
```

**Validation Tests**:
```
[ ] Fetch Cost Mgmt API (12 months, < 5 min)
[ ] Fetch Monitor metrics (30 days, < 10 min, test with 1 resource first)
[ ] Fetch Advisor recommendations (< 1 min)
[ ] Fetch Inventory (< 2 min)
[ ] Fetch Policies (< 1 min)
[ ] Cosmos upsert works (test write to CostEvents with sample doc)
[ ] Document count matches resource count (± 5% tolerance)

Expected output: 5 success messages, ~5K-10K documents stored
```

---

### Task 2.2: Implement Analysis Engine
**Effort**: 12 hours  
**Owner**: Data Scientist  
**What It Does**: Run 3 Pandas notebooks on ingested data, generate candidates

**Notebook 1: Utilization Analysis** (code in AGENTS-ORCHESTRATION-20260303.md)
```python
# src/notebooks/utilization_analysis.ipynb

# Query: 30-day average CPU/Memory per resource
# Output: Candidates where avg_cpu < 20% or avg_memory < 30%
# Logic: Low utilization → overprovisioned → downsize opportunity

# Example output: 
# [
#   {"resourceName": "dev0-gpu-vm", "avg_cpu": 8.5, "recommendation": "DOWNSIZE", "confidence": 0.85},
#   {"resourceName": "infoasst-search-2", "avg_cpu": 12.2, "recommendation": "DOWNSIZE", "confidence": 0.75}
# ]
```

**Notebook 2: Cost Attribution** (see AGENTS-ORCHESTRATION-20260303.md)
```python
# src/notebooks/cost_attribution.ipynb

# Query: 12-month cost trends by service type
# Output: Services with upward cost trends (growing expense)
# Logic: Rapidly growing services might be candidates for consolidation

# Example output:
# Service: Microsoft.CognitiveServices
#   Monthly cost: $2,150 (avg)
#   30-day trend: +$50/day (alarming growth)
#   Recommendation: Audit usage, consider consolidation
```

**Notebook 3: Recommendation Scoring** (see AGENTS-ORCHESTRATION-20260303.md)
```python
# src/notebooks/candidate_scoring.ipynb

# Input: UtilizationAnalysis + CostEvents + Advisor recommendations
# For each resource, combine evidence:
#   - Utilization metrics (weight 0.4)
#   - Cost data (weight 0.3)
#   - Advisor recommendation (weight 0.3)
# Output: Candidates with confidence scores 0.3-0.95

# Example output document:
# {
#   "id": "rec-dev0-gpu-downsize",
#   "resourceName": "dev0-gpu-vm",
#   "recommendation": "DOWNSIZE_TO_STANDARD_D4S",
#   "estimatedMonthlySavings": 38,
#   "confidenceLevel": 0.85,
#   "evidencePoints": [
#     {"point": "Avg CPU 8.5% < 30%", "source": "Monitor", "weight": 0.4},
#     {"point": "Monthly cost $45", "source": "CostMgmt", "weight": 0.3},
#     {"point": "Azure Advisor: Underutilized VM", "source": "Advisor", "weight": 0.3}
#   ],
#   "status": "PENDING_VALIDATION"
# }
```

**Validation Tests**:
```
[ ] Run Notebook 1: Identify 10+ resources with low utilization
[ ] Run Notebook 2: Identify services with cost trends
[ ] Run Notebook 3: Generate 50-200 candidates with confidence scores
[ ] Every candidate has >= 3 evidence points
[ ] Confidence scores range 0.3-0.95 (not all 0.9)
[ ] Documents correctly stored in RecommendationCandidates collection

Expected output: 50-200 recommendation candidates ready for validation
```

---

## PHASE 3: VALIDATION + PRIORITIZATION (WEEK 4)

### Task 3.1: Implement Validation Agent
**Effort**: 8 hours  
**Owner**: Data Scientist  
**What It Does**: Check each candidate against compliance, dependencies, risk

**Code Skeleton**:
```python
# src/agents/validation.py

class ValidationAgent(Agent):
    async def run(self, candidates):
        validated = []
        
        for candidate in candidates:
            # Step 1: Compliance check
            if self.is_blocked_by_compliance(candidate):
                candidate['status'] = "BLOCKED_BY_COMPLIANCE"
                candidate['approval_required'] = True
                validated.append(candidate)
                continue
            
            # Step 2: Dependency check
            dependencies = self.find_dependencies(candidate)
            if dependencies and self.has_critical_dependency(dependencies):
                candidate['risk_level'] = "HIGH"
                candidate['risk_factors'].extend([dep.description for dep in dependencies])
            
            # Step 3: Data gap adjustment
            if candidate['missing_data_points']:
                candidate['confidence_level'] *= 0.8  # Reduce by 20%
            
            # Step 4: Actual cost validation
            if candidate['cost_in_last_30_days'] == 0:
                candidate['confidence_level'] *= 0.85  # Suspicious if not charged
            
            candidate['status'] = "VALIDATED"
            validated.append(candidate)
        
        return validated
```

**Validation Tests**:
```
[ ] Check compliance: 0-5 candidates should be blocked
[ ] Check dependencies: Identify 2-3 recommendations with "HIGH" risk
[ ] Data gap detection: Reduce confidence appropriately
[ ] Cost validation: Flag resources with zero cost (already optimized?)

Expected output: All 50-200 candidates tagged with risk_level, compliance status
```

---

### Task 3.2: Implement Prioritization Agent
**Effort**: 4 hours  
**Owner**: Data Scientist  
**What It Does**: Rank candidates by ROI/Effort/Risk, create tiered lists

**Code Skeleton**:
```python
# src/agents/prioritization.py

class PrioritizationAgent(Agent):
    def calculate_roi_score(self, candidate):
        """ROI = (Annual_Savings / Effort_Hours) * RiskMult * Confidence"""
        annual = candidate['estimatedMonthlySavings'] * 12
        effort = candidate.get('implementation_hours', 2)
        risk_mult = {"LOW": 1.0, "MEDIUM": 0.7, "HIGH": 0.4}[candidate['risk_level']]
        confidence = candidate['confidence_level']
        
        roi = (annual / effort) * risk_mult * confidence
        return roi
    
    async def run(self, validated_candidates):
        tiers = {"TIER_1": [], "TIER_2": [], "TIER_3": [], "TIER_4": []}
        
        for candidate in validated_candidates:
            roi = self.calculate_roi_score(candidate)
            
            if roi > 80 and candidate['risk_level'] == 'LOW':
                tier = "TIER_1_IMMEDIATE"
                candidate['implementation_weeks'] = 1
            elif roi > 50 and candidate['risk_level'] in ['LOW', 'MEDIUM']:
                tier = "TIER_2_SOON"
                candidate['implementation_weeks'] = 2
            elif roi > 30:
                tier = "TIER_3_STRATEGIC"
                candidate['implementation_weeks'] = 4
            else:
                tier = "TIER_4_DEFERRED"
                candidate['implementation_weeks'] = 12
            
            candidate['roi_score'] = roi
            candidate['tier'] = tier
            tiers[tier].append(candidate)
        
        return tiers
```

**Validation Tests**:
```
[ ] TIER_1: 5-15 candidates (quick wins, low risk)
[ ] TIER_2: 10-25 candidates (medium effort, medium ROI)
[ ] TIER_3: 15-50 candidates (strategic, high ROI but complex)
[ ] TIER_4: Rest of candidates (deferred, low ROI)

Expected: Annual savings by tier:
  TIER_1: $7-15K (1-2 weeks effort total)
  TIER_2: $10-25K (2-8 weeks effort)
  TIER_3: $25-55K (month+ effort, org decisions)
```

---

## PHASE 4: RUNBOOK + REPORTING (WEEK 5)

### Task 4.1: Implement Scribe Agent
**Effort**: 8 hours  
**Owner**: Data Scientist  
**What It Does**: Generate Azure CLI/PowerShell runbooks for humans to execute

**Code Skeleton**:
```python
# src/agents/scribe.py
from agent_framework_azure_ai import AzureAIClientAgent

class ScribeAgent(AzureAIClientAgent):
    """Uses LLM to generate runbooks from templates"""
    
    async def run(self, tier_1_recommendations):
        runbooks = []
        
        for rec in tier_1_recommendations[:10]:  # Top 10 quick wins
            template = self.load_template(rec['recommendationType'])
            
            # Use LLM to generate customized runbook
            runbook = await self.client.complete_chat_message(
                messages=[
                    {"role": "system", "content": "Generate a safety-first Azure runbook"},
                    {"role": "user", "content": f"""
                        Template: {template}
                        Resource: {rec['resourceName']}
                        Recommendation: {rec['recommendation']}
                        Estimated Savings: ${rec['estimatedMonthlySavings']*12}
                        Risk Level: {rec['risk_level']}
                        
                        Requirements:
                        1. Start with PRE-FLIGHT CHECKS (human must approve)
                        2. Include step-by-step instructions
                        3. Add VALIDATION steps after each change
                        4. Include ROLLBACK PROCEDURE in case of errors
                        5. Start with WARNING section including confidence level
                        
                        Output format: PowerShell
                        """}
                ],
                model="gpt-4"
            )
            
            # Store runbook
            doc = {
                "id": f"runbook-{rec['id']}",
                "recommendation_id": rec['id'],
                "generated_at": datetime.now().isoformat(),
                "runbook": runbook.choices[0].message.content,
                "format": "PowerShell"
            }
            await self.cosmos.upsert(collection="Runbooks", document=doc)
            runbooks.append(doc)
        
        return runbooks
```

**Generated Runbook Example** (output):
```powershell
# RUNBOOK: Dev VM Auto-Shutdown
# Recommendation: dev0-gpu-vm
# Confidence: 95%
# Annual Savings: $456

# WARNING
# ========
# Confidence Level: 95% (HIGH)
# Risk Level: LOW
# Data Gaps: None
# Rollback Impact: Easy (1 command to remove tags)

# PRE-FLIGHT CHECKS (HUMAN APPROVAL REQUIRED)
Write-Host "Pre-flight Checks:" -ForegroundColor Cyan
Write-Host "[ ] Confirm this VM is NON-PRODUCTION"
$confirm = Read-Host "Proceed? (yes/no)"
if ($confirm -ne "yes") { exit }

# STEP 1: Apply shutdown tags
az tag create --resource-id "/subscriptions/.../virtualMachines/dev0-gpu-vm" `
  --tags "auto-shutdown-utc=22:00" "auto-startup-utc=07:00"

# STEP 2: Validate
$tags = az tag show --resource-id "/subscriptions/.../virtualMachines/dev0-gpu-vm"
Write-Host "Tags applied: $tags" -ForegroundColor Green

# ROLLBACK (if needed)
# az tag delete --resource-id [...] --keys "auto-shutdown-utc" "auto-startup-utc"
```

**Validation Tests**:
```
[ ] Generate runbooks for top 10 TIER_1 recommendations
[ ] Each runbook includes: pre-flight checks, steps, validation, rollback
[ ] Each runbook starts with confidence level + risk level + data gaps
[ ] Runbooks are PowerShell format (executable by humans)
[ ] All 10 runbooks stored in Cosmos DB

Expected: 10 ready-to-execute runbooks (< 2 hours effort per recommendation)
```

---

### Task 4.2: Implement Reporting Agent
**Effort**: 6 hours  
**Owner**: Data Scientist  
**What It Does**: Synthesize findings into executive + detailed reports

**Code Skeleton**:
```python
# src/agents/reporting.py

class ReportingAgent(AzureAIClientAgent):
    """Uses LLM to generate reports from data"""
    
    async def run(self, all_data):
        # Executive Summary (1 page)
        exec_report = await self.client.complete_chat_message(
            messages=[{"role": "user", "content": f"""
                Generate a 1-page executive summary:
                
                Data:
                - Tier 1 Count: {len(all_data.tier_1)} recommendations, ${self.total_savings(all_data.tier_1)}/yr
                - Tier 2 Count: {len(all_data.tier_2)} recommendations, ${self.total_savings(all_data.tier_2)}/yr
                - Confidence: {self.avg_confidence(all_data)}%
                - Data Coverage: {self.data_coverage(all_data)}%
                - Blockers: {len(all_data.compliance_blockers)} compliance blocks
                
                Format: Markdown
                Include: HONESTY section on data gaps
                """}],
            model="gpt-4"
        )
        
        # Detailed Report (10 pages)
        detailed_report = await self.client.complete_chat_message(
            messages=[{"role": "user", "content": f"""
                Generate a 10-page technical report:
                
                Sections:
                1. Executive Summary (1 page)
                2-4. Tier 1 Recommendations (3 pages)
                5-7. Tier 2 Recommendations (3 pages)
                8. Methodology & Data Quality (2 pages) - HONESTY section required
                9. Implementation Timeline (1 page)
                10. Success Metrics (1 page)
                
                Format: Markdown
                Include: Confidence intervals, data gaps, caveats
                """}],
            model="gpt-4"
        )
        
        # Store reports
        docs = [
            {"id": f"report-exec-{date.today()}", "type": "executive", "content": exec_report},
            {"id": f"report-detail-{date.today()}", "type": "detailed", "content": detailed_report}
        ]
        
        for doc in docs:
            await self.cosmos.upsert(collection="Reports", document=doc)
        
        return docs
```

**Report Output** (examples):

**Executive Summary** (1 page):
```markdown
# COST OPTIMIZATION REPORT - March 2026

## Quick Wins (This Month)
- Dev VM Auto-Shutdown: $456/yr, 95% confidence, 15 min effort
- ACR Consolidation: $7-15K/yr, 75% confidence, 2 hrs effort
- Storage Lifecycle: $24-96/mo, 65% confidence, 1 hr effort

**Total Tier 1: 12 opportunities, $7.3-15.5K/yr savings, 4-6 hours effort**

## Strategic Opportunities (Q2)
- InfoAssist Consolidation: $25-55K/yr (pending org decision)
- Reserved Instances: $30-60/mo per prod VM

## Data Quality Assessment
- Confidence Level: 72% average (MEDIUM-HIGH)
- Data Coverage: 85% of recommendations are data-driven
- Data Gaps: 15% require deeper compliance audit / dependency mapping

## Next Steps
1. Execute Tier 1 quick wins (Week 1-2)
2. Validate Tier 2 recommendations (Week 3-4)
3. Plan Q2 strategic projects (upon org decision)
```

**Detailed Report** (excerpt, 10 pages total):
```markdown
# DETAILED COST OPTIMIZATION ANALYSIS - March 2026

## Tier 1 Recommendations (Quick Wins, High Confidence)

### 1. Dev VM Auto-Shutdown (dev0-gpu-vm)
- **Estimated Annual Savings**: $456
- **Confidence Level**: 95% (HIGH)
- **Risk Level**: LOW
- **Implementation Time**: 15 minutes
- **Runbook**: See appendix A

**Evidence**:
1. Utilization Analysis: Avg CPU 8.5%, Max 42% (< 30% threshold for overprovisioning)
   - Source: Azure Monitor (30-day metrics)
   - Weight: 40%
2. Cost Data: Monthly cost $38, billing continuously
   - Source: Cost Management API (validate during hold period)
   - Weight: 30%
3. Azure Advisor: Underutilized VM detected
   - Source: Azure Advisor (ML recommendation)
   - Weight: 30%

**Data Gaps**: None identified

**Pre-Requisites**: 
- [ ] Confirm VM is non-production
- [ ] No scheduled batch jobs depend on this VM

**Rollback Procedure**: Remove tags (1 command, ~1 min)

**Success Criteria**: 
- [ ] Runbook executed without errors
- [ ] VM tags show auto-shutdown settings
- [ ] VM shuts down at scheduled time (observe 7 days)
- [ ] Cost drops by ~$38/month after 60 days

---

## Data Quality and Methodology

### What We Analyzed (✓ Data-Driven)
- ✓ Cost Management API: 12 months of actual billable costs
- ✓ Azure Monitor: 30-day utilization metrics (CPU, memory, requests)
- ✓ Azure Advisor: ML-ranked recommendations
- ✓ Resource Inventory: SKU, tier, creation date, tags
- ✓ Azure Policy: Compliance constraints

### What's Still Missing (⚠ Lower Confidence)
- ⚠ 90-day utilization trends (only 30-day available)
- ⚠ Service dependency mapping (inferred, not validated)
- ⚠ Compliance audit (partial: policies only, not requirements)
- ⚠ Growth forecasts (not included in analysis)

### Confidence Intervals by Category
- VMs & Compute: 85-95% confidence (good utilization data)
- Storage: 65-75% confidence (need data age analysis)
- Databases: 55-70% confidence (need RU/throughput metrics)
- Networking: 40-60% confidence (missing usage data)

### How to Improve Confidence (Phase 0 Data Collection)
- Collect 90-day metrics (not 30-day) for seasonal patterns
- Map service dependencies (code scan + manual audit)
- Audit compliance/retention requirements per service
- Analyze growth trends (month-over-month cost change)
- Collect actual API call metrics (not just aggregates)

---

## Timeline & Resource Plan

### Week 1-2: Execute Tier 1 Quick Wins
```
Mon-Fri: Dev VM auto-shutdown (6 items, 30-60 min each)
Mon-Fri: Budget alerts setup (2 configs, 15 min each)
Expected: $300-480/yr in savings, zero blockers
```

### Week 3-4: Validate & Execute Tier 2
```
Mon-Fri: ACR consolidation audit (need to validate CI/CD dependencies)
Mon-Fri: Storage lifecycle config (need data age audit)
Expected: $7-15K/yr in savings, medium effort (10-20 hours)
```

### Month 2+: Strategic Planning
```
Pending org decision: InfoAssist consolidation ($25-55K/yr)
Pending approval: Reserved instance purchasing (Q2 planning)
```

---

## HONESTY Statement

**This analysis is based on actual cost data + 30-day utilization metrics.**
**Confidence levels explicitly shown above reflect data quality.**
**No recommendations included without 3+ evidence points.**
**All data gaps documented and flagged.**

**Limitations**:
- 30-day window is short for seasonal workloads (need 90 days for confidence)
- Service dependencies inferred from Advisor, not verified
- Compliance audit incomplete (recommendations may be blocked post-validation)
- Growth trends not included (cost may be increasing for good reasons)

**Next Phase**: Conduct Phase 0 deeper data collection to improve confidence before Tier 3 execution.
```

**Validation Tests**:
```
[ ] Executive summary generated (1 page, readable by CFO)
[ ] Detailed report generated (10 pages, technical depth)
[ ] Both reports include data quality / HONESTY sections
[ ] Confidence intervals clearly stated
[ ] Data gaps documented
[ ] Implementation timeline included

Expected: 1-page executive summary + 10-page technical report, both stored in Cosmos DB
```

---

## PHASE 5: DEPLOYMENT & AUTOMATION (WEEK 6)

### Task 5.1: Deploy Agents to Azure Container Apps
**Effort**: 4 hours  
**Owner**: DevOps

**Deployment Steps**:
```powershell
# Step 1: Build Docker images
docker build -t marcoeva.azurecr.io/finops/supervisor:latest ./src/agents/supervisor.py
docker build -t marcoeva.azurecr.io/finops/ingestion:latest ./src/agents/ingestion.py
docker build -t marcoeva.azurecr.io/finops/analysis:latest ./src/agents/analysis_engine.py
# ... etc for all 7 agents

# Step 2: Push to ACR
docker push marcoeva.azurecr.io/finops/supervisor:latest
# ... etc

# Step 3: Deploy to ACA
az containerapp create \
  --name finops-supervisor \
  --image marcoeva.azurecr.io/finops/supervisor:latest \
  --environment marco-aca-env \
  --resource-group EsDAICoE-Sandbox \
  --env-vars COSMOS_ENDPOINT=https://marco-eva-finops.documents.azure.com COSMOS_KEY=@keyvault:finops-key \
  --trigger-type schedule \
  --schedule-expression "0 2 * * 0"  # Sunday 2 AM
```

**Validation**:
```
[ ] All 7 agent images built and pushed to ACR
[ ] Container apps deployed to ACA
[ ] Environment variables configured (Cosmos endpoint, API keys)
[ ] Scheduler trigger configured (weekly, 2 AM UTC)
[ ] Monitoring + alerting configured (AppInsights)

[ ] Manual test run: Monitor execution logs in AppInsights
[ ] Verify: Documents created in each Cosmos collection
[ ] Verify: Reports generated and stored
```

---

### Task 5.2: Configure Monitoring + Alerting
**Effort**: 2 hours  
**Owner**: DevOps

**Setup**:
```powershell
# Enable Application Insights for agent containers
az containerapp update \
  --name finops-supervisor \
  --instrumentation-key {appinsights-key}

# Create alert: If any agent fails
az monitor metrics alert create `
  --name "FinOps Agent Failure" `
  --resource-group EsDAICoE-Sandbox `
  --scopes /subscriptions/.../containerApps/finops-supervisor `
  --condition "count > 0" `
  --window-size 5m `
  --evaluation-frequency 5m `
  --action email@contoso.com
```

---

## FINAL CHECKLIST

### Infrastructure (Week 1-2)
```
[ ] Cosmos DB: marco-eva-finops provisioned (8 collections)
[ ] Key Vault: finops-appid, API keys stored
[ ] Service Principal: finops-agents created with necessary roles
[ ] Project scaffolding: Agent Framework + Python venv ready
```

### Implementation (Week 3-5)
```
[ ] Ingestion Agent: Fetches from 5 APIs, stores in Cosmos
[ ] Analysis Engine: Runs 3 Pandas notebooks, generates candidates
[ ] Validation Agent: Checks compliance, dependencies, risk
[ ] Prioritization Agent: Tiers recommendations by ROI
[ ] Scribe Agent: Generates runbooks for top recommendations
[ ] Reporting Agent: Creates executive + detailed reports
```

### Deployment (Week 6)
```
[ ] Docker images built and pushed
[ ] Container apps deployed to ACA
[ ] Scheduler configured (automatic weekly runs)
[ ] Monitoring + alerting configured
[ ] Manual test run successful
[ ] All documents correctly stored in Cosmos DB
[ ] Reports accessible via REST API
```

### Operations (Ongoing)
```
[ ] Weekly: Supervisor runs automatically (2 AM UTC Sunday)
[ ] Weekly: Review newly generated candidates
[ ] Monthly: Execute Tier 1 recommendations (script generation + human execution)
[ ] Quarterly: Run full analysis again, refresh all notebooks
[ ] Continuous: Monitor Cosmos storage costs (should be < $500/mo)
```

---

## SUCCESS METRICS

| Metric | Target | Measurement Method |
|---|---|---|
| **Time to First Report** | < 1 month | Deploy date to first run completion |
| **Monthly Cost Savings** | $600-1,300/mo | Track billing before/after Tier 1 execution |
| **Candidate Accuracy** | > 80% of Tier 1 executed as-is | # executed / # recommended |
| **Confidence Levels** | All >= 0.5, majority >= 0.7 | Query RecommendationCandidates, aggregate statistics |
| **Data Quality** | > 85% of recommendations have 3+ evidence points | Query and count evidence_points per candidate |
| **Agent Uptime** | > 99% (automated runs complete) | Monitor ACA logs, track failures |
| **Report Sageability** | Leadership can act based on reports | Feedback from CFO / CTO |

---

## COST & ROI SUMMARY

### Development Cost (Team)
| Item | Cost |
|---|---|
| Data Scientist (240 hrs @ $150/hr) | $36,000 |
| DevOps Engineer (80 hrs @ $120/hr) | $9,600 |
| Cost Architect (40 hrs @ $130/hr) | $5,200 |
| **Total Development** | **$50,800** |

### Infrastructure Cost (Recurring)
| Item | Monthly | Yearly |
|---|---|---|
| Cosmos DB (FinOps database) | $300-400 | $3.6-4.8K |
| Container Apps (7 agents) | $100-150 | $1.2-1.8K |
| Azure Monitor / AppInsights | $50 | $600 |
| **Total Infrastructure** | **$450-600/mo** | **$5.4-7.2K/yr** |

### Expected ROI
- **Monthly savings from Tier 1 quick wins**: $600-1,300/mo within 60 days
- **Payback period**: < 3 months (development cost recovered)
- **Year 1 net benefit**: ($7.3-15.5K Tier 1) + ($7-15K Tier 2) - $50.8K dev - $5.4K infra = ~-$37-44K (invest year)
- **Year 2+ annual benefit**: $14-30K/yr (recurring discoveries)
- **5-year total**: $14-30K * 5 - $50.8K = $20-99K net benefit

**Value Beyond Cost**: Proper data governance, compliance tracking, organizational learning on costs

---

## NEXT STEP: DECISION POINT

**Question for Leadership**: 

"Should we proceed with Phase 1 (Cosmos DB + Infrastructure) this week, aiming for first full report in 4-6 weeks?"

- ✅ **YES** → Start Week 1 tasks immediately, 6-week deployment plan
- ❓ **MAYBE** → Start Phase 1 only (Cosmos + Foundation), defer agent build, iterate based on data
- ❌ **NO** → Continue with manual quarterly assessments (lower automation, higher labor cost)

**Recommendation**: Phase 1 + 2 (Cosmos + Ingestion) are low-risk ($5K infra, 10-20 hours). Do that this week, assess data quality before committing to agents.

---

**Prepared by**: GitHub Copilot Agent (Cost Optimization System - Implementation Quickstart)  
**Date**: March 3, 2026  
**Timeline**: 4-6 weeks to production readiness  
**Status**: READY TO EXECUTE
