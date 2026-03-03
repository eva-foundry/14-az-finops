# Cost Optimization Agents - Orchestration Plan
**Date**: March 3, 2026  
**Framework**: Microsoft Agent Framework (Python)  
**Scope**: Multi-agent system for end-to-end cost analysis execution  
**Architecture Pattern**: Supervisor Agent + Specialist Agents (fan-out/fan-in)

---

## AGENT TOPOLOGY

```
                    ┌─────────────────────┐
                    │ SUPERVISOR AGENT    │
                    │ (Orchestrator)      │
                    │ - Triggers workflows│
                    │ - Monitors progress │
                    │ - Reports results   │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
        ┌─────▼──────┐   ┌─────▼──────┐  ┌─────▼──────┐
        │  INGESTION │   │  ANALYSIS  │  │ VALIDATION │
        │  AGENT     │   │  ENGINE    │  │  AGENT     │
        │ (Parallel) │   │ (Parallel) │  │(Sequential)│
        └──────┬─────┘   └──────┬─────┘  └─────┬──────┘
               │                │              │
        ┌──────▼──────┐   ┌──────▼──────┐  ┌──▼────────────┐
        │ Cost Mgmt   │   │ Utilization │  │ Compliance    │
        │ API Puller  │   │ Scorer      │  │ Checker       │
        │             │   │             │  │ Dependency    │
        │ + 4 more    │   │ Cost Trend  │  │ Analyzer      │
        │ subtasks    │   │ Analyzer    │  │ Risk Assessor │
        └─────────────┘   └─────────────┘  └───┬───────────┘
                                                │
                                        ┌───────▼────────┐
                                        │ PRIORITIZATION │
                                        │    AGENT       │
                                        │ (Ranked Lists) │
                                        └───────┬────────┘
                                                │
                                    ┌───────────┴───────────┐
                                    │                       │
                            ┌───────▼──────┐      ┌────────▼────┐
                            │    SCRIBE    │      │  REPORTING  │
                            │    AGENT     │      │   AGENT     │
                            │ (Runbooks)   │      │ (Summaries) │
                            └──────────────┘      └─────────────┘
```

---

## AGENT SPECIFICATIONS

### AGENT 1: SUPERVISOR (Orchestrator)

**Purpose**: Orchestrate the entire workflow, trigger sub-agents, handle errors  
**Framework Role**: Supervisor Agent (from Microsoft Agent Framework)  
**Language**: Python

**Inputs**:
- Trigger signal (scheduled: daily/weekly, or manual: REST API)
- Configuration: Which subscriptions, date ranges, cost thresholds

**Process Flow**:
```python
from agent_framework_core import Agent, AgentState
from agent_framework_azure_ai import AzureAIClientAgent

class FinOpsOrchestrator(Agent):
    async def run(self, trigger_signal):
        """Main orchestration loop"""
        
        # Step 1: Initialize state
        state = AgentState(
            subscription_id="d2d4e571-e0f2-4f6c-901a-f88f7669bcba",
            run_id=generate_run_id(),
            start_time=datetime.now(),
            status="IN_PROGRESS"
        )
        
        # Step 2: Trigger Ingestion Agent (parallel: 5 tasks)
        ingestion_results = await self.invoke_agent(
            agent="ingestion_agent",
            tasks=[
                {"task": "fetch_cost_mgmt_api", "lookback_days": 365},
                {"task": "fetch_monitor_metrics", "lookback_days": 30},
                {"task": "fetch_advisor_recommendations"},
                {"task": "fetch_resource_inventory"},
                {"task": "fetch_compliance_rules"}
            ],
            parallel=True
        )
        
        # Wait for all ingestion tasks to complete
        for task in ingestion_results:
            if task.status != "COMPLETE":
                await self.log_error(f"Ingestion failed: {task.error}")
                state.blockers.append(task.error)
        
        # Step 3: Trigger Analysis Engine (depends on ingestion)
        analysis_results = await self.invoke_agent(
            agent="analysis_engine",
            inputs=ingestion_results.success,
            notebooks=[
                "utilization_analysis.ipynb",
                "cost_attribution.ipynb",
                "candidate_scoring.ipynb"
            ]
        )
        
        # Step 4: Trigger Validation Agent (sequential, each step waits for previous)
        validation_results = await self.invoke_agent(
            agent="validation_agent",
            candidates=analysis_results.recommendations,
            # Validation tasks run in order: compliance → dependencies → risk
            sequential=True
        )
        
        # Step 5: Trigger Prioritization Agent (after validation)
        prioritized = await self.invoke_agent(
            agent="prioritization_agent",
            validated_candidates=validation_results.recommendations
        )
        
        # Step 6: Trigger Scribe Agent (async, parallel tasks for each tier)
        runbooks = await self.invoke_agent(
            agent="scribe_agent",
            recommendations=prioritized.tier_1 + prioritized.tier_2,
            # Generate runbooks for top 10 recommendations
            max_runbooks=10,
            parallel=True
        )
        
        # Step 7: Trigger Reporting Agent (final synthesis)
        report = await self.invoke_agent(
            agent="reporting_agent",
            data={
                "ingestion": ingestion_results,
                "analysis": analysis_results,
                "validation": validation_results,
                "prioritized": prioritized,
                "runbooks": runbooks
            }
        )
        
        # Step 8: Store execution record
        state.status = "COMPLETE"
        state.end_time = datetime.now()
        await self.store_execution_history(
            run_id=state.run_id,
            status=state.status,
            duration_seconds=(state.end_time - state.start_time).total_seconds(),
            recommendations_count=len(prioritized.all_recommendations),
            blockers=state.blockers
        )
        
        return {
            "status": "SUCCESS",
            "report": report,
            "execution_history": state
        }
    
    async def invoke_agent(self, agent, **kwargs):
        """Helper to invoke sub-agents with error handling"""
        try:
            result = await agent(**kwargs)
            return result
        except Exception as e:
            await self.log_error(f"Agent {agent.name} failed: {str(e)}")
            raise

# Entry point
orchestrator = FinOpsOrchestrator(name="FinOpsOrchestrator")

@app.post("/workflows/cost-optimization/run")
async def trigger_workflow():
    """HTTP trigger for workflow"""
    result = await orchestrator.run(trigger_signal="manual")
    return result
```

**Outputs**:
- Execution history (what ran, what succeeded, what failed)
- All downstream results (ingestion → analysis → validation → prioritization → reports)
- Blockers/errors (for manual intervention)

**Tools It Uses**:
- Microsoft Agent Framework: `invoke_agent()`, `AgentState`, parallel/sequential orchestration
- Cosmos DB: `store_execution_history()`
- Logging: `log_error()`, `log_info()`

---

### AGENT 2: INGESTION AGENT (Data Collection)

**Purpose**: Fetch data from 5 Azure APIs, normalize, store in Cosmos DB  
**Framework Role**: Tool-using Agent (calls Azure APIs as tools)  
**Language**: Python  
**Parallelization**: 5 concurrent tasks (one per data source)

**Inputs**:
```python
{
  "subscription_id": "d2d4e571-e0f2-4f6c-901a-f88f7669bcba",
  "tasks": [
    {"task": "fetch_cost_mgmt_api", "lookback_days": 365},
    {"task": "fetch_monitor_metrics", "lookback_days": 30},
    ...,
  ],
  "parallel": True
}
```

**Process (5 Parallel Sub-Tasks)**:

**Task 1: Cost Management API**
```python
async def fetch_cost_mgmt_api(subscription_id, lookback_days=365):
    """Fetch actual billable costs from Cost Management API"""
    
    # Use Azure CLI or SDK
    cost_data = await azure_client.cost_management.query(
        subscription_id=subscription_id,
        time_period={
            "from": (datetime.now() - timedelta(days=lookback_days)).isoformat(),
            "to": datetime.now().isoformat()
        },
        granularity="Daily",
        grouping=[
            {"type": "Dimension", "name": "ResourceType"},
            {"type": "Dimension", "name": "ResourceGroup"},
            {"type": "Tag", "name": "ai_costcenter"}
        ]
    )
    
    # Normalize + store
    for row in cost_data.rows:
        doc = {
            "id": f"{row['date']}-{row['subscriptionId']}-{row['resourceType']}",
            "subscriptionId": subscription_id,
            "date": row['date'],
            "resourceType": row['resourceType'],
            "resourceGroup": row['resourceGroup'],
            "cost": row['PreTaxCost'],
            "currency": "USD",
            "costCenter": row.get('ai_costcenter'),
            "source": "CostManagement",
            "ttl": 7776000  # 90 days
        }
        await cosmos_client.upsert(collection="CostEvents", document=doc)
    
    return {"status": "SUCCESS", "documents_stored": len(cost_data.rows)}
```

**Task 2: Azure Monitor Metrics**
```python
async def fetch_monitor_metrics(subscription_id, lookback_days=30):
    """Fetch CPU, Memory, Request rate from Azure Monitor"""
    
    # Get all resources
    resources = await azure_client.resources.list(subscription_id)
    
    # For each resource, fetch metrics
    for resource in resources:
        metrics_data = await azure_client.monitor.metrics(
            resource_id=resource['id'],
            timespan=f"P{lookback_days}D",
            interval="PT1H",  # 1-hour intervals
            metrics=["CpuPercentage", "MemoryPercentage", "RequestCount", "ErrorRate"]
        )
        
        # Aggregate to daily
        daily_metrics = aggregate_to_daily(metrics_data)
        
        doc = {
            "id": f"{resource['name']}-{datetime.now().date()}",
            "resourceId": resource['id'],
            "resourceName": resource['name'],
            "resourceType": resource['type'],
            "date": datetime.now().date(),
            "metrics": {
                "cpuPercentage": {
                    "avg": daily_metrics['cpu_avg'],
                    "max": daily_metrics['cpu_max'],
                    "p95": daily_metrics['cpu_p95']
                },
                "memoryPercentage": {...},
                "requestCount": {...}
            },
            "source": "AzureMonitor",
            "ttl": 7776000
        }
        await cosmos_client.upsert(collection="ResourceMetrics", document=doc)
    
    return {"status": "SUCCESS", "documents_stored": len(resources)}
```

**Task 3: Azure Advisor (ML Recommendations)**
```python
async def fetch_advisor_recommendations():
    """Fetch Microsoft's ML-ranked cost optimization recommendations"""
    
    advisor_recs = await azure_client.advisor.recommendations.list(
        filter="Category eq 'Cost'",
        max_items=500
    )
    
    # Each recommendation has: shortDescription, estimatedMonthlySavings, impact, confidenceRating
    for rec in advisor_recs:
        # Try to match to resource in our inventory
        matching_resource = await find_resource_by_name(rec.impacted_resource)
        
        doc = {
            "id": f"advisor-{uuid4()}",
            "advisorCategory": rec.category.name,
            "advisorImpact": rec.impact.name,
            "confidenceRating": rec.confidence_rating.name,
            "estimatedMonthlySavings": rec.estimated_monthly_savings,
            "description": rec.short_description,
            "impactedResource": matching_resource.get('id'),
            "source": "AzureAdvisor",
            "ttl": 7776000
        }
        await cosmos_client.upsert(collection="AdvisorRecommendations", document=doc)
    
    return {"status": "SUCCESS", "documents_stored": len(advisor_recs)}
```

**Task 4: Resource Inventory**
```python
async def fetch_resource_inventory(subscription_id):
    """Fetch current SKU, tier, tags, creation date"""
    
    inventory = await azure_client.resources.list(
        subscription_id=subscription_id,
        select="id,name,type,sku,tags,createdTime,provisioningState,properties"
    )
    
    for resource in inventory:
        doc = {
            "id": resource['id'],
            "subscriptionId": subscription_id,
            "name": resource['name'],
            "type": resource['type'],
            "sku": resource.get('sku'),
            "tier": resource.get('properties', {}).get('tier'),
            "tags": resource.get('tags', {}),
            "createdTime": resource.get('createdTime'),
            "provisioningState": resource.get('provisioningState'),
            "source": "ResourceInventory",
            "ttl": 7776000
        }
        await cosmos_client.upsert(collection="ResourceInventory", document=doc)
    
    return {"status": "SUCCESS", "documents_stored": len(inventory)}
```

**Task 5: Compliance Rules (Manual + Policy)**
```python
async def fetch_compliance_rules(subscription_id):
    """Fetch Azure Policy assignments + manual compliance docs"""
    
    # Azure Policy
    policies = await azure_client.policy.assignments.list(scope=f"/subscriptions/{subscription_id}")
    
    # Convert policies to compliance rules
    for policy in policies:
        doc = {
            "id": f"policy-{policy.name}",
            "policyName": policy.display_name,
            "description": policy.description,
            "scope": policy.scope,
            "effect": policy.properties.get('policyDefinitionId'),
            "source": "AzurePolicy",
            "ttl": 2592000  # 30 days (policies change less frequently)
        }
        await cosmos_client.upsert(collection="ComplianceRules", document=doc)
    
    # Manual compliance rules (stored JSON)
    manual_rules = load_manual_compliance_rules()  # From config file
    for rule in manual_rules:
        await cosmos_client.upsert(collection="ComplianceRules", document=rule)
    
    return {"status": "SUCCESS", "documents_stored": len(policies) + len(manual_rules)}
```

**Outputs**:
- 5 result documents (one per task): status, document count, errors
- Normalized documents stored in Cosmos DB (6 collections)
- Execution timing (how long each task took)

**Tools It Uses**:
- Azure Cost Management SDK
- Azure Monitor SDK
- Azure Advisor SDK
- Azure Resource Management SDK
- Cosmos DB client

---

### AGENT 3: ANALYSIS ENGINE (Data Science)

**Purpose**: Run Pandas notebooks on ingested data, score recommendations  
**Framework Role**: Tool-using Agent (executes Jupyter notebooks)  
**Language**: Python + Pandas  
**Execution**: Sequential (Notebook 1 → 2 → 3)

**Inputs**:
```python
{
  "notebooks": [
    "utilization_analysis.ipynb",
    "cost_attribution.ipynb",
    "candidate_scoring.ipynb"
  ],
  "cosmos_collections": ["CostEvents", "ResourceMetrics", "ResourceInventory"]
}
```

**Notebook 1: Utilization Analysis**
```python
# Input: ResourceMetrics for 30 days
# Output: UtilizationAnalysis container with downsize candidates

import pandas as pd
from azure.cosmos import CosmosClient

# Query 30-day average utilization per resource
query = """
SELECT 
  c.resourceName,
  c.resourceType,
  AVG(c.metrics.cpuPercentage.avg) as avg_cpu,
  MAX(c.metrics.cpuPercentage.max) as max_cpu,
  AVG(c.metrics.memoryPercentage.avg) as avg_memory
FROM ResourceMetrics c
WHERE c.date >= @start_date
GROUP BY c.resourceName, c.resourceType
"""

results = list(cosmos_client.query_items(
    container="ResourceMetrics",
    query=query,
    parameters=[{"name": "@start_date", "value": (datetime.now() - timedelta(days=30)).isoformat()}]
))

df = pd.DataFrame(results)

# Scoring logic
def calculate_downsize_score(row):
    """Returns: (score, recommendation, confidence)"""
    avg_cpu = row['avg_cpu']
    max_cpu = row['max_cpu']
    
    if max_cpu > 85:
        return (0.9, "UPSIZE", 0.8)  # Might need bigger SKU
    elif avg_cpu < 20 and max_cpu < 75:
        return (0.2, "DOWNSIZE", 0.85)  # Definitely overprovisioned
    elif avg_cpu < 40 and max_cpu < 80:
        return (0.45, "CONSIDER_DOWNSIZE", 0.65)  # Likely overprovisioned
    else:
        return (0.85, "RIGHTSIZE", 0.75)  # Appropriately sized

df['downsize_score'] = df.apply(calculate_downsize_score, axis=1)

# Store results in UtilizationAnalysis container
for idx, row in df.iterrows():
    doc = {
        "id": f"util-{row['resourceType']}-{datetime.now().strftime('%Y-%m')}",
        "resourceType": row['resourceType'],
        "month": datetime.now().strftime('%Y-%m'),
        "statistics": {
            "totalResources": len(df[df['resourceType'] == row['resourceType']]),
            "avgCpuPercentage": row['avg_cpu'],
            "maxCpuPercentage": row['max_cpu']
        },
        "candidateDownsizes": [{
            "resourceName": row['resourceName'],
            "currentScore": row['downsize_score'][0],
            "recommendation": row['downsize_score'][1],
            "confidence": row['downsize_score'][2]
        }],
        "generatedAt": datetime.now().isoformat()
    }
    cosmos_client.upsert(collection="UtilizationAnalysis", document=doc)
```

**Notebook 2: Cost Attribution & Trends**
```python
# Input: CostEvents for 12 months
# Output: Cost trends, growth anomalies, service rankings

query = """
SELECT c.date, c.resourceType, SUM(c.cost) as daily_cost
FROM CostEvents c
GROUP BY c.date, c.resourceType
ORDER BY c.date DESC
"""

costs_df = pd.DataFrame(cosmos_client.query_items("CostEvents", query))

# Calculate 30-day rolling average + trend
costs_df['rolling_30day'] = costs_df.groupby('resourceType')['daily_cost'].rolling(30).mean()
costs_df['trend_slope'] = costs_df.groupby('resourceType')['daily_cost'].apply(
    lambda x: np.polyfit(range(len(x)), x, 1)[0]  # Linear regression slope
)

# Identify services with upward cost trends (growing costs)
growth_services = costs_df[costs_df['trend_slope'] > 0.5].groupby('resourceType')['trend_slope'].mean().sort_values(ascending=False)

doc = {
    "id": f"cost-trends-{datetime.now().strftime('%Y-%m')}",
    "month": datetime.now().strftime('%Y-%m'),
    "costTrends": {
        "totalMonthlyCost": costs_df['daily_cost'].sum(),
        "growthServices": growth_services.to_dict(),
        "declineServices": ...
    },
    "generatedAt": datetime.now().isoformat()
}
cosmos_client.upsert(collection="CostTrends", document=doc)
```

**Notebook 3: Recommendation Candidate Scoring**
```python
# Input: UtilizationAnalysis + CostEvents + AdvisorRecommendations
# Output: RecommendationCandidates with confidence scores

# For each resource, combine evidence points
for resource in inventory:
    evidence_points = []
    
    # Evidence 1: Utilization metrics
    util_data = cosmos_client.get_item(
        container="UtilizationAnalysis",
        item_id=f"util-{resource['type']}-{datetime.now().strftime('%Y-%m')}"
    )
    if util_data and util_data['candidateDownsizes']:
        evidence_points.append({
            "point": f"Utilization {util_data['avgCpuPercentage']}% < 30%",
            "source": "AzureMonitor",
            "weight": 0.4
        })
    
    # Evidence 2: Cost data
    cost_data = get_resource_cost(resource['id'], lookback_days=30)
    evidence_points.append({
        "point": f"Monthly cost: ${cost_data['cost']:.2f}",
        "source": "CostManagement",
        "weight": 0.3
    })
    
    # Evidence 3: Advisor recommendations
    advisor_match = match_advisor_recommendation(resource, advisor_recs)
    if advisor_match:
        evidence_points.append({
            "point": f"Microsoft Advisor: {advisor_match['description']}",
            "source": "AzureAdvisor",
            "weight": 0.3
        })
    
    # Calculate confidence = sum(weight * indicator) / sum(weight)
    confidence = sum(ep['weight'] * 1.0 for ep in evidence_points) / sum(ep['weight'] for ep in evidence_points)
    
    # Store candidate
    candidate = {
        "id": f"rec-{resource['name']}-{uuid4()}",
        "resourceName": resource['name'],
        "resourceType": resource['type'],
        "recommendationType": "DOWNSIZE",
        "estimatedMonthlySavings": calculate_savings(resource),
        "confidenceLevel": confidence,
        "evidencePoints": evidence_points,
        "dataGaps": identify_missing_data(resource),
        "status": "PENDING_VALIDATION"
    }
    cosmos_client.upsert(collection="RecommendationCandidates", document=candidate)
```

**Outputs**:
- UtilizationAnalysis documents (per service type, per month)
- CostTrends documents (monthly cost summary + growth/decline analysis)
- RecommendationCandidates documents (50-200 new candidates, each with confidence score 0.3-0.95)

**Tools It Uses**:
- Pandas: Data aggregation, scoring, trending
- NumPy: Linear regression (trend calculation)
- Cosmos DB client: Queries and upserts

---

### AGENT 4: VALIDATION AGENT (Risk Assessment)

**Purpose**: Check each candidate against compliance, dependencies, risk  
**Framework Role**: Tool-using Agent (queries Cosmos DB + Azure APIs)  
**Language**: Python  
**Execution**: Sequential per candidate (can't parallelize due to interdependencies)

**Process**:
```python
async def validate_recommendation(candidate):
    """For each candidate, assess risk, compliance, dependencies"""
    
    # Task 1: Compliance Check
    compliance_blocks = []
    for rule in cosmos_client.query(collection="ComplianceRules"):
        if rule.applies_to(candidate.resourceType):
            if rule.blocks_action(candidate.action):
                compliance_blocks.append({
                    "rule": rule.name,
                    "reason": rule.description
                })
    
    if compliance_blocks:
        candidate.status = "BLOCKED_BY_COMPLIANCE"
        candidate.compliance_blockers = compliance_blocks
        candidate.approval_required = True
        candidate.approvers.append("Compliance Officer")
        return candidate
    
    # Task 2: Dependency Check
    # Query: What other resources depend on this one?
    dependencies = [...]  # Query dependency map
    for dep in dependencies:
        if dep.criticality == "CRITICAL":
            candidate.risk_level = "HIGH"
            candidate.risk_factors.append(f"Critical: {dep.description}")
    
    # Task 3: Data Gap Assessment
    # If missing key data, reduce confidence
    missing_data = []
    if not candidate.has_utilization_data_30days:
        missing_data.append("30-day utilization metrics")
        candidate.confidence_level *= 0.8
    if not candidate.has_compliance_audit:
        missing_data.append("Compliance audit results")
        candidate.confidence_level *= 0.9
    
    candidate.data_gaps = missing_data
    
    # Task 4: Actual Cost Validation
    # Verify resource is actually incurring cost
    actual_cost = cosmos_client.get_item("CostEvents", candidate.resourceId)
    if actual_cost is None or actual_cost['cost'] == 0:
        candidate.confidence_level *= 0.85  # Not being billed (suspicious)
    
    # Final assessment
    candidate.status = "VALIDATED"
    candidate.validated_at = datetime.now().isoformat()
    candidate.validated_by = "validation_agent"
    
    return candidate

# Main loop
for candidate in cosmos_client.query(collection="RecommendationCandidates", where="status = 'PENDING_VALIDATION'"):
    validated = await validate_recommendation(candidate)
    cosmos_client.upsert(collection="RecommendationCandidates", document=validated)
```

**Outputs**:
- Updated RecommendationCandidates with:
  - Status: BLOCKED, VALIDATED, DEFERRED_LOW_CONFIDENCE
  - Risk level: LOW, MEDIUM, HIGH, CRITICAL
  - Compliance blockers (if any): Rule names + reasons
  - Data gaps: Missing data points that reduce confidence
  - Updated confidence level (original * adjustment factors)

**Tools It Uses**:
- Cosmos DB: Query compliance rules, dependencies
- Azure Advisor API: Verify recommendations
- Azure Monitor: Check if resource is actively used

---

### AGENT 5: PRIORITIZATION AGENT (ROI Ranking)

**Purpose**: Rank recommendations by ROI / Effort / Risk  
**Framework Role**: Tool-using Agent (scoring + sorting)  
**Language**: Python

**Algorithm**:
```python
# Calculate ROI score for each recommendation
def calculate_roi_score(candidate):
    """ROI = (Annual Savings / Implementation Effort) * Risk Multiplier * Confidence"""
    
    annual_savings = candidate['estimatedMonthlySavings'] * 12
    implementation_effort = candidate.get('implementation_hours', 2)  # Default 2 hours
    confidence = candidate['confidence_level']
    
    # Risk multiplier (lower risk = higher multiplier)
    risk_multiplier = {
        "LOW": 1.0,
        "MEDIUM": 0.7,
        "HIGH": 0.4,
        "CRITICAL": 0.1
    }[candidate.get('risk_level', 'MEDIUM')]
    
    roi_score = (annual_savings / implementation_effort) * risk_multiplier * confidence
    return roi_score

# Tier candidates
for candidate in cosmos_client.query(collection="RecommendationCandidates", where="status = 'VALIDATED'"):
    roi = calculate_roi_score(candidate)
    
    if roi > 80 and candidate['risk_level'] == 'LOW':
        tier = "TIER_1_IMMEDIATE"
    elif roi > 50 and candidate['risk_level'] in ['LOW', 'MEDIUM']:
        tier = "TIER_2_SOON"
    elif roi > 30:
        tier = "TIER_3_STRATEGIC"
    else:
        tier = "TIER_4_DEFERRED"
    
    candidate['roi_score'] = roi
    candidate['tier'] = tier
    candidate['prioritized_at'] = datetime.now().isoformat()
    
    cosmos_client.upsert(collection="RecommendationCandidates", document=candidate)

# Generate summary
tier_1 = cosmos_client.query(collection="RecommendationCandidates", where="tier = 'TIER_1_IMMEDIATE'")
tier_2 = cosmos_client.query(collection="RecommendationCandidates", where="tier = 'TIER_2_SOON'")

summary = {
    "id": f"priority-summary-{datetime.now().strftime('%Y-%m-%d')}",
    "tier_1_count": len(tier_1),
    "tier_1_total_savings": sum(c['estimatedMonthlySavings'] * 12 for c in tier_1),
    "tier_2_count": len(tier_2),
    "tier_2_total_savings": sum(c['estimatedMonthlySavings'] * 12 for c in tier_2),
    "generated_at": datetime.now().isoformat()
}
cosmos_client.upsert(collection="PrioritySummary", document=summary)
```

**Outputs**:
- Updated RecommendationCandidates with: `tier` (TIER_1/2/3/4), `roi_score`
- PrioritySummary: Executive view of tiered opportunities

**Tools It Uses**:
- Cosmos DB: Query, score, tier recommendations

---

### AGENT 6: SCRIBE AGENT (Runbook Generation)

**Purpose**: Generate Azure CLI/PowerShell runbooks for humans to execute  
**Framework Role**: LLM-using Agent (Copilot) with tools  
**Language**: Python + Azure CLI + PowerShell  
**Execution**: Parallel (each runbook independent)

**Tools Available**:
```python
# Template library for different recommendation types
TEMPLATES = {
    "DOWNSIZE_VM": "templates/vm-downsize.ps1",
    "DELETE_RESOURCE": "templates/delete-resource.ps1",
    "ENABLE_AUTOSCALE": "templates/autoscale-config.ps1",
    "MOVE_TO_COOL_STORAGE": "templates/storage-lifecycle.ps1",
    "DELETE_TAG": "templates/resource-tag-delete.ps1"
}

async def generate_runbook(candidate):
    """Generate step-by-step runbook for executing recommendation"""
    
    template_name = candidate['recommendationType']
    template = TEMPLATES[template_name]
    
    # Use LLM to customize template for this specific resource
    runbook = await copilot_client.generate_runbook(
        template=template,
        resource_name=candidate['resourceName'],
        resource_id=candidate['resourceId'],
        estimated_savings=candidate['estimatedMonthlySavings'],
        risk_level=candidate['risk_level'],
        data_gaps=candidate['data_gaps'],
        instructions="Generate a detailed, safety-first runbook with pre-flight checks, steps, validation, and rollback"
    )
    
    # Add HONESTY labels
    runbook.prepend(f"""
# WARNING: Confidence Level = {candidate['confidence_level']*100:.0f}%
# Missing Data: {', '.join(candidate['data_gaps'])}
# Risk Level: {candidate['risk_level']}
# Estimated Annual Savings: ${candidate['estimatedMonthlySavings']*12:.2f} (ESTIMATED, not validated)
    """)
    
    # Store runbook
    doc = {
        "id": f"runbook-{candidate['id']}",
        "recommendation_id": candidate['id'],
        "generated_at": datetime.now().isoformat(),
        "generated_by": "scribe_agent",
        "runbook_text": runbook,
        "format": "PowerShell"
    }
    cosmos_client.upsert(collection="Runbooks", document=doc)
    
    return runbook
```

**Generated Runbook Example** (output for humans):
```powershell
# RUNBOOK: Auto-Shutdown for Dev VM (dev0-gpu-vm)
# Recommendation ID: rec-auto-shutdown-20260303
# Confidence: 95%
# Estimated Annual Savings: $456

# PRE-FLIGHT CHECKS
Write-Host "Step 1: Pre-flight Checks" -ForegroundColor Cyan
Write-Host "[ ] Verify VM is non-production" -Foreground White
$isProd = Read-Host "Is this a production VM? (Y/N)" 
if ($isProd -eq 'Y') { Write-Error "ABORT: Cannot shutdown production VM"; exit 1 }

# TAG FOR SHUTDOWN
az tag create --resource-id "/subscriptions/.../resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Compute/virtualMachines/dev0-gpu-vm" `
  --tags "auto-shutdown-utc=22:00" "auto-startup-utc=07:00"

# VALIDATE
Write-Host "Step 2: Validation"
$tags = az resource show --ids "/subscriptions/.../providers/Microsoft.Compute/virtualMachines/dev0-gpu-vm" --query "tags" | ConvertFrom-Json
Write-Host "Tags applied: " $tags -ForegroundColor Green

# MONITOR
Write-Host "You can now monitor shutdown behavior in Azure Portal for 7 days before confirming success"
```

**Outputs**:
- Runbook documents stored in Cosmos DB
- Runbooks formatted for PowerShell / Azure CLI
- Each runbook includes: pre-flight checks, steps, validation, rollback

**Tools It Uses**:
- LLM (Copilot): Runbook generation from templates
- Cosmos DB: Store runbooks

---

### AGENT 7: REPORTING AGENT (Executive Summary)

**Purpose**: Synthesize all data into executive summaries  
**Framework Role**: LLM-using Agent (Copilot)  
**Language**: Python + Markdown

**Inputs**:
- All predecessor agent outputs
- Configuration: Report format (executive 1-pager vs. detailed 10-pager vs. both)

**Process**:
```python
async def generate_report(data):
    """Generate executive + detailed reports"""
    
    # Collect data from all agents
    tier_1_count = len(data.prioritized.tier_1)
    tier_1_savings = sum(c['estimatedMonthlySavings'] * 12 for c in data.prioritized.tier_1)
    
    tier_2_count = len(data.prioritized.tier_2)
    tier_2_savings = sum(c['estimatedMonthlySavings'] * 12 for c in data.prioritized.tier_2)
    
    avg_confidence = statistics.mean(c['confidence_level'] for c in data.validation.all_recommendations)
    data_coverage = len([c for c in data.validation.all_recommendations if c['data_gaps'] == []]) / len(data.validation.all_recommendations)
    
    # Generate executive summary (1 page)
    exec_summary = await copilot_client.generate_text(
        prompt=f"""
        Generate a 1-page executive summary of cost optimization findings:
        
        - Tier 1 (Quick Wins): {tier_1_count} opportunities, ${tier_1_savings:,.0f}/yr savings
        - Tier 2 (Medium-term): {tier_2_count} opportunities, ${tier_2_savings:,.0f}/yr savings
        - Average Confidence: {avg_confidence*100:.0f}%
        - Data Coverage: {data_coverage*100:.0f}%
        - Blockers: {len(data.validation.compliance_blockers)} compliance issues
        
        Format: Markdown
        Tone: Professional, data-driven, honest about limitations
        Include: HONESTY section explaining data gaps and confidence levels
        """,
        max_tokens=2000
    )
    
    # Generate detailed findings (10 pages)
    detailed = await copilot_client.generate_text(
        prompt=f"""
        Generate a detailed cost optimization report (10 pages):
        
        Section 1: Executive Summary (1 page)
        Section 2-4: Tier 1 Recommendations (3 pages, 2-3 recommendations each with full breakdown)
        Section 5-7: Tier 2 Recommendations (3 pages)
        Section 8: Data Quality & Methodology (2 pages, HONESTY section)
        Section 9: Implementation Timeline (1 page, Gantt chart)
        Section 10: Success Metrics & Next Steps (1 page)
        
        For each recommendation, include:
        - Description
        - Evidence points (with sources)
        - Confidence level
        - Risk assessment
        - Implementation runbook reference
        - Rollback procedure
        
        Include: Explicit confidence intervals, data gaps, and caveats
        Format: Markdown with tables
        """,
        max_tokens=10000
    )
    
    # Store reports
    reports = {
        "executive_summary": {
            "id": f"report-exec-{datetime.now().strftime('%Y-%m-%d')}",
            "type": "executive",
            "content": exec_summary,
            "pages": 1,
            "generated_at": datetime.now().isoformat()
        },
        "detailed": {
            "id": f"report-detailed-{datetime.now().strftime('%Y-%m-%d')}",
            "type": "detailed",
            "content": detailed,
            "pages": 10,
            "generated_at": datetime.now().isoformat()
        }
    }
    
    for report in reports.values():
        cosmos_client.upsert(collection="Reports", document=report)
    
    return reports
```

**Outputs**:
- Executive Summary Report (1 page, leadership-ready)
- Detailed Report (10 pages, technical depth)
- Both stored in Cosmos DB
- Also accessible via REST API

**Tools It Uses**:
- LLM (Copilot) for text generation
- Cosmos DB: Store reports

---

## ORCHESTRATION SUMMARY

| Agent | Role | Input | Output | Tools |
|---|---|---|---|---|
| **Supervisor** | Orchestrate workflow | Trigger signal | Execution status | Agent Framework, Cosmos DB |
| **Ingestion** | Collect data | Subscr. ID | 5 data source docs | Cost Mgmt API, Monitor, Advisor, Resource, Policy APIs |
| **Analysis** | Score candidates | Cost/Metric data | 50-200 candidates | Pandas, NumPy, Cosmos queries |
| **Validation** | Risk assessment | Candidates | Risk/Compliance flags | Cosmos compliance, dependency queries |
| **Prioritization** | ROI ranking | Validated candidates | Tiered lists | ROI scoring algorithm |
| **Scribe** | Runbooks | Approved items | Executable scripts | LLM, PowerShell templates |
| **Reporting** | Summarize results | All agent outputs | Executive + detailed reports | LLM, Markdown |

---

## DEPLOYMENT ARCHITECTURE

### Hosting Options

**Option 1: Azure Container Apps (Recommended)**
```yaml
# deploy-finops-agents.yaml
containers:
  - name: finops-supervisor
    image: marcoeva.azurecr.io/finops/supervisor:latest
    env:
      COSMOS_ENDPOINT: https://marco-eva-finops.documents.azure.com:443
      COSMOS_KEY: [from Key Vault]
    triggers:
      - type: schedule
        cron: "0 2 * * 0"  # Every Sunday at 2 AM
  
  - name: finops-ingestion
    image: marcoeva.azurecr.io/finops/ingestion:latest
    replicas: 1  # No parallelization needed (5 tasks run sequentially)
    cpu: 1.0
    memory: 2Gi
  
  - name: finops-analysis-engine
    image: marcoeva.azurecr.io/finops/analysis:latest
    replicas: 1
    cpu: 2.0  # Pandas is CPU-intensive
    memory: 4Gi
    
  # ... rest of agents
```

**Option 2: Azure Functions**
```csharp
[FunctionName("FinOpsOrchestrator")]
public static async Task Run(
    [TimerTrigger("0 2 * * 0")] TimerInfo timer,  // Sunday 2 AM
    IAsyncCollector<QueueMessage> orchestrationQueue)
{
    // Trigger workflow
    await orchestrationQueue.AddAsync(new QueueMessage { WorkflowId = Guid.NewGuid() });
}
```

**Option 3: GitHub Actions (Scheduled)**
```yaml
# .github/workflows/finops-analysis.yml
name: Cost Optimization Analysis
on:
  schedule:
    - cron: '0 2 * * 0'  # Sunday 2 AM

jobs:
  run-analysis:
    runs-on: ubuntu-latest
    steps:
      - name: Run FinOps Workflow
        run: |
          python finops_supervisor.py \
            --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba \
            --workflow full
```

---

## DEPLOYMENT CHECKLIST

```
[ ] Cosmos DB: marco-eva-finops database created
[ ] Collections: All 8 containers created with TTL
[ ] Access: Agents have read/write permissions
[ ] Credentials: Stored in Key Vault (Cost Mgmt API key, Monitor API key, etc.)
[ ] Agent Framework: Installed (pip install agent-framework-azure-ai==1.0.0b*)
[ ] Notebooks: Deployed (utilization, cost, scoring scripts)
[ ] Runbook templates: Deployed (7 templates for different scenarios)
[ ] LLM: Azure OpenAI or Foundry endpoint configured
[ ] Scheduler: Trigger configured (ACA timer / Functions / GitHub Actions)
[ ] Monitoring: App Insights configured for agent execution logs
[ ] Alerting: Notification on workflow failure

[ ] HONESTY: All agents have confidence-level labels
[ ] HONESTY: All reports include data gap sections
[ ] HONESTY: No recommendations without 3+ evidence points
```

---

**Architecture Prepared**: March 3, 2026  
**Framework**: Microsoft Agent Framework (Python)  
**Pattern**: Supervisor + Specialist Agents  
**Status**: READY FOR IMPLEMENTATION
