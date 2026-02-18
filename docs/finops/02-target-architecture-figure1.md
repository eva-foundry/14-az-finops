# Figure 1: FinOps Hub High-Level Architecture

**Document**: 02-target-architecture.md  
**Type**: Flowchart  
**Purpose**: Complete FinOps Hubs implementation showing cost data flow from Azure subscriptions through ingestion, analytics, attribution, and reporting.

---

## Diagram

```mermaid
flowchart TB
    subgraph Azure_Subscriptions["Azure Subscriptions"]
        ESDC_DEV["EsDAICoESub<br/>(Dev/Stage)<br/>$255K/mo"]
        ESDC_PROD["EsPAICoESub<br/>(Production)<br/>$42K/mo"]
    end
    
    subgraph Cost_Mgmt["Cost Management"]
        EXPORT1["Daily Export<br/>EsDAICoESub-Daily"]
        EXPORT2["Daily Export<br/>EsPAICoESub-Daily"]
    end
    
    subgraph Landing_Zone["marcosandboxfinopshub (ADLS Gen2)"]
        RAW["Container: raw/<br/>Landing zone for exports"]
        PROCESSED["Container: processed/<br/>Normalized data"]
        ARCHIVE["Container: archive/<br/>Long-term retention"]
        CHECKPOINT["Container: checkpoint/<br/>Pipeline state"]
    end
    
    subgraph Event_Orchestration["Event & Orchestration"]
        EVENTGRID["Event Grid<br/>System Topic"]
        ADF["Azure Data Factory<br/>marco-sandbox-finops-adf"]
    end
    
    subgraph Analytics["Analytics & Storage"]
        ADX["Azure Data Explorer<br/>marco-finops-adx"]
        ADX_DB[("finopsdb<br/>- raw_costs<br/>- normalized_costs<br/>- apim_usage")]
    end
    
    subgraph Usage_Tracking["Usage Attribution"]
        APIM["Azure APIM<br/>marco-sandbox-apim<br/>(Policy: inject headers)"]
        APPINS["App Insights<br/>marco-sandbox-appinsights"]
    end
    
    subgraph Reporting["Reporting & Visualization"]
        PBI["Power BI<br/>KQL Direct Query"]
        REPORTS["Dashboards:<br/>- Cost Trends<br/>- Allocation by App<br/>- Tag Compliance"]
    end
    
    subgraph Governance["Governance"]
        POLICY["Azure Policy<br/>- Require Tags<br/>- Enforce Exports"]
        RBAC["RBAC<br/>Managed Identities"]
        PRIVATE["Private Endpoints<br/>+ NSGs"]
    end
    
    ESDC_DEV --> EXPORT1
    ESDC_PROD --> EXPORT2
    EXPORT1 -->|"CSV (gzip)<br/>55+ columns"| RAW
    EXPORT2 -->|"CSV (gzip)<br/>55+ columns"| RAW
    RAW -->|"BlobCreated Event"| EVENTGRID
    EVENTGRID -->|"Trigger Pipeline"| ADF
    ADF -->|"1. Decompress<br/>2. Validate Schema<br/>3. Ingest"| ADX_DB
    ADF -->|"Move processed"| PROCESSED
    ADF -->|"Save Manifest"| CHECKPOINT
    
    APIM -->|"x-costcenter<br/>x-caller-app<br/>x-environment"| APPINS
    APPINS -->|"Export Logs"| ADF
    ADF -->|"Ingest telemetry"| ADX_DB
    
    ADX -->|"KQL Queries"| PBI
    PBI --> REPORTS
    
    POLICY -.->|"Enforce"| ESDC_DEV
    POLICY -.->|"Enforce"| ESDC_PROD
    RBAC -.->|"Authorize"| ADF
    RBAC -.->|"Authorize"| ADX
    PRIVATE -.->|"Secure"| Landing_Zone
    PRIVATE -.->|"Secure"| ADX
    
    classDef costMgmt fill:#FFE5B4,stroke:#FF8C00,stroke-width:2px
    classDef storage fill:#B4D7FF,stroke:#0078D4,stroke-width:2px
    classDef compute fill:#D4F1D4,stroke:#107C10,stroke-width:2px
    classDef reporting fill:#FFD4E5,stroke:#E81123,stroke-width:2px
    classDef security fill:#E5E5E5,stroke:#605E5C,stroke-width:2px
    
    class EXPORT1,EXPORT2 costMgmt
    class RAW,PROCESSED,ARCHIVE,CHECKPOINT storage
    class ADF,ADX,ADX_DB compute
    class PBI,REPORTS reporting
    class POLICY,RBAC,PRIVATE security
```

---

## Key Components

1. **Azure Subscriptions**: EsDAICoESub (Dev/Stage $255K/mo), EsPAICoESub (Production $42K/mo)
2. **Cost Management**: Daily exports in CSV.gz format with 55+ columns
3. **Landing Zone**: ADLS Gen2 hierarchical storage (raw → processed → archive)
4. **Event Orchestration**: Event Grid triggers ADF pipelines on blob creation
5. **Analytics**: Azure Data Explorer (ADX) with KQL query engine
6. **Usage Attribution**: APIM policies inject caller headers for cost allocation
7. **Reporting**: Power BI DirectQuery dashboards
8. **Governance**: Azure Policy enforcement, RBAC, private endpoints

---

## Color Legend

- **Orange** (#FFE5B4): Cost Management resources
- **Blue** (#B4D7FF): Storage resources
- **Green** (#D4F1D4): Compute/Analytics resources
- **Pink** (#FFD4E5): Reporting resources
- **Gray** (#E5E5E5): Governance/Security controls

---

**Conversion Instructions**:

To convert this markdown file to PNG or PDF:

```bash
# Using mermaid-cli (mmdc)
npm install -g @mermaid-js/mermaid-cli
mmdc -i 02-target-architecture-figure1.md -o 02-target-architecture-figure1.png
mmdc -i 02-target-architecture-figure1.md -o 02-target-architecture-figure1.pdf

# Or use online tools
# https://mermaid.live/
# https://kroki.io/
```
