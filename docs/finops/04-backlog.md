# 04 - Backlog (ADO-Ready Epics, Features, Tasks)

**Document Type**: Operational  
**Phase**: Planning  
**Audience**: [project-managers, engineers, devops]  
**Last Updated**: 2026-02-17 08:20 AM ET  
**Author**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Sprint Duration**: 2 weeks

---

## Backlog Structure

This backlog follows Azure DevOps hierarchy: **Epic** → **Feature** → **Task**.  
Each task includes clear acceptance criteria suitable for definition of done (DoD).

**Estimation**: T-shirt sizing (XS=1pt, S=2pt, M=3pt, L=5pt, XL=8pt)  
**Priority**: P0 (Critical), P1 (High), P2 (Medium), P3 (Low)

---

## Epic 1: FinOps Hubs Foundation

**Goal**: Establish storage infrastructure, event routing, and validation framework.  
**Business Value**: Enable centralized cost data collection with automated ingestion triggers.  
**Effort**: 13 points (Sprints 1-2)

### Feature 1.1: ADLS Gen2 Landing Zone

**User Story**: As a FinOps analyst, I need structured storage containers to organize raw, processed, and archived cost data for lifecycle management.

#### Task 1.1.1: Create Storage Containers (XS)
**Description**: Create 4 containers in `marcosandboxfinopshub`: raw, processed, archive, checkpoint.

**Acceptance Criteria**:
- [ ] All 4 containers visible via `az storage container list`
- [ ] Container access level: Private (no anonymous access)
- [ ] Test file upload succeeds in each container
- [ ] Documentation: Screenshot of Portal Containers blade
- [ ] Evidence artifact: `tools/finops/out/storage_containers.json`

**Effort**: 1 point  
**Priority**: P0  
**Assigned To**: DevOps Engineer

---

#### Task 1.1.2: Configure Lifecycle Management Policy (S)
**Description**: Implement auto-tiering to Cool (90 days) and Archive (180 days) for cost optimization.

**Acceptance Criteria**:
- [ ] Bicep module `storage-lifecycle.bicep` deployed successfully
- [ ] Policy visible in Portal → Storage Account → Lifecycle management
- [ ] Rule count: 2 (MoveRawToCool, MoveArchiveToArchive)
- [ ] Test blob shows scheduled tier change in metadata
- [ ] Evidence: `az storage account management-policy show` output saved

**Effort**: 2 points  
**Priority**: P1  
**Assigned To**: Cloud Architect

---

#### Task 1.1.3: Migrate Existing Exports to Raw Container (M)
**Description**: Reorganize current `costs/` blobs into hierarchical `raw/costs/{subscription}/{YYYY}/{MM}/` structure.

**Acceptance Criteria**:
- [ ] Script `migrate-costs-to-raw.sh` creates copies in raw/ preserving hierarchy
- [ ] Validation: Row count spot-check for 5 sample CSVs (source vs. destination)
- [ ] Original `costs/` container renamed to `costs-old` (not deleted)
- [ ] Documentation: Migration log with blob count and total size

**Effort**: 3 points  
**Priority**: P0  
**Assigned To**: Data Engineer

---

### Feature 1.2: Export Configuration Update

**User Story**: As a cost data engineer, I need exports to land in the correct raw/ container with proper event notifications.

#### Task 1.2.1: Update Cost Management Export Destinations (S)
**Description**: Reconfigure portal exports to target `raw/costs/{SubscriptionName}` path.

**Acceptance Criteria**:
- [ ] Both exports (EsDAICoESub-Daily, EsPAICoESub-Daily) updated in Portal
- [ ] Manual trigger succeeds and blob lands in `raw/costs/.../YYYY/MM/` path
- [ ] Export history shows updated root folder path
- [ ] Evidence: Screenshots of export configuration + successful run

**Effort**: 2 points  
**Priority**: P0  
**Assigned To**: FinOps Administrator

---

### Feature 1.3: Event Grid Integration

**User Story**: As an automation engineer, I need blob creation events to trigger ingestion pipelines automatically.

#### Task 1.3.1: Verify Event Grid System Topic (S)
**Description**: Confirm existing system topic `marcosandboxfinopshub-52dd...` is active and receiving events.

**Acceptance Criteria**:
- [ ] System topic status: Succeeded
- [ ] Metrics show events in last 24 hours (after export runs)
- [ ] Event types: `Microsoft.Storage.BlobCreated` for `/raw/costs/` prefix
- [ ] Evidence: Event Grid Metrics screenshot showing event count

**Effort**: 2 points  
**Priority**: P0  
**Assigned To**: Cloud Architect

---

#### Task 1.3.2: Create Event Subscription to ADF (M)
**Description**: Wire Event Grid to trigger ADF pipeline `ingest-costs-to-adx` on blob creation.

**Acceptance Criteria**:
- [ ] Event subscription created: `finops-ingest-trigger`
- [ ] Filter: Prefix `/raw/costs/`, Suffix `.csv.gz`
- [ ] Test: Upload sample CSV → ADF pipeline triggered within 2 minutes
- [ ] Delivery success rate: 100% (check Event Grid Metrics)
- [ ] Evidence: Event subscription JSON + ADF run history

**Effort**: 3 points  
**Priority**: P0  
**Assigned To**: Data Engineer

---

## Epic 2: Analytics & Ingestion

**Goal**: Deploy ADX cluster, create schema, and automate CSV ingestion from Blob to ADX.  
**Business Value**: Enable large-scale cost analytics with KQL queries and Power BI integration.  
**Effort**: 21 points (Sprints 3-4)

### Feature 2.1: ADX Cluster Deployment

**User Story**: As a FinOps analyst, I need a scalable analytics platform to query millions of cost records with sub-second response time.

#### Task 2.1.1: Deploy ADX Cluster (Dev SKU) (M)
**Description**: Deploy `marcofinopsadx` cluster in canadacentral with Dev SKU (2 nodes, D11_v2).

**Acceptance Criteria**:
- [ ] Bicep module `adx-cluster.bicep` deploys without errors
- [ ] Cluster status: Running (Portal → Azure Data Explorer Clusters)
- [ ] Database `finopsdb` created with 31-day hot cache, 5-year retention
- [ ] Query editor accessible: `https://dataexplorer.azure.com/clusters/marcofinopsadx`
- [ ] Test query succeeds: `.show databases | where DatabaseName == "finopsdb"`
- [ ] Evidence: Cluster URI, database name, principal ID output saved

**Effort**: 3 points  
**Priority**: P0  
**Assigned To**: Cloud Architect

---

#### Task 2.1.2: Create ADX Schema and Tables (L)
**Description**: Execute KQL script to create `raw_costs`, `apim_usage` tables, materialized view, and ingestion mappings.

**Acceptance Criteria**:
- [ ] Tables created: `.show tables` returns 2 rows (raw_costs, apim_usage)
- [ ] Ingestion mapping: `.show table raw_costs ingestion csv mappings` returns CostExportMapping
- [ ] Materialized view: `.show materialized-views` returns normalized_costs
- [ ] Function: `.show functions` returns AllocateCostByApp
- [ ] Policies applied: partitioning (by Date), retention (5 years), update (IngestionTime)
- [ ] Evidence: Screenshots of KQL command results

**Effort**: 5 points  
**Priority**: P0  
**Assigned To**: Data Architect

---

#### Task 2.1.3: Test ADX Ingestion with Sample CSV (S)
**Description**: Validate ingestion mapping by manually uploading 5-row sample CSV.

**Acceptance Criteria**:
- [ ] Sample CSV ingested using `.ingest inline` or ADF test run
- [ ] Query validation: `raw_costs | count` returns 5
- [ ] Column types validated: `raw_costs | getschema` matches expected types
- [ ] No parsing errors in `.show ingestion failures`
- [ ] Evidence: ADX query results screenshot

**Effort**: 2 points  
**Priority**: P0  
**Assigned To**: Data Engineer

---

### Feature 2.2: ADF Pipeline Development

**User Story**: As a data engineer, I need automated pipelines to decompress, validate, and ingest cost CSVs into ADX without manual intervention.

#### Task 2.2.1: Create Managed Identity for ADF (XS)
**Description**: Deploy user-assigned managed identity `mi-finops-adf` with required RBAC roles.

**Acceptance Criteria**:
- [ ] Managed identity created: `az identity show -n mi-finops-adf`
- [ ] Role 1: Storage Blob Data Contributor on marcosandboxfinopshub
- [ ] Role 2: ADX Database Ingestor on finopsdb
- [ ] Role assignments validated: `az role assignment list --assignee <principalId>`
- [ ] ADX principal check: `.show database finopsdb principals` includes mi-finops-adf
- [ ] Evidence: Role assignment outputs saved

**Effort**: 1 point  
**Priority**: P0  
**Assigned To**: Cloud Architect

---

#### Task 2.2.2: Create ADF Linked Services (S)
**Description**: Configure connections to Blob Storage and ADX using managed identity authentication.

**Acceptance Criteria**:
- [ ] Linked service: `ls_marcosandbox_blob` (Azure Blob Storage, managed identity auth)
- [ ] Linked service: `ls_marcofinops_adx` (Azure Data Explorer, managed identity auth)
- [ ] Test connection succeeds for both linked services
- [ ] Evidence: Screenshots of linked service configurations

**Effort**: 2 points  
**Priority**: P0  
**Assigned To**: Data Engineer

---

#### Task 2.2.3: Create ADF Datasets (S)
**Description**: Define datasets for source (Blob CSV) and sink (ADX table).

**Acceptance Criteria**:
- [ ] Dataset: `ds_blob_cost_csv` (DelimitedText, gzip compression, parameterized blobUrl)
- [ ] Dataset: `ds_adx_raw_costs` (AzureDataExplorer, table=raw_costs, mapping=CostExportMapping)
- [ ] Preview data validates schema for both datasets
- [ ] Evidence: Dataset JSON definitions exported

**Effort**: 2 points  
**Priority**: P0  
**Assigned To**: Data Engineer

---

#### Task 2.2.4: Implement Pipeline: ingest-costs-to-adx (L)
**Description**: Build pipeline with decompression, validation, and copy activities.

**Acceptance Criteria**:
- [ ] Pipeline activities: Get Metadata → Copy Data → Update Checkpoint
- [ ] Parameters: blobUrl (string, passed from Event Grid)
- [ ] Copy activity: Source=ds_blob_cost_csv, Sink=ds_adx_raw_costs, Enable staging
- [ ] Error handling: Retry policy (3 attempts), failure alert (email/webhook)
- [ ] Test run with sample blob succeeds
- [ ] ADX validation: Row count matches CSV (minus header)
- [ ] Evidence: Pipeline JSON + successful debug run screenshot

**Effort**: 5 points  
**Priority**: P0  
**Assigned To**: Data Engineer

---

#### Task 2.2.5: Implement Pipeline: backfill-historical (L)
**Description**: Create pipeline to process 500+ historical blobs (12 months) in parallel.

**Acceptance Criteria**:
- [ ] Pipeline activities: Get Metadata (list blobs) → ForEach (parallelism=5) → Execute ingest pipeline
- [ ] Progress tracking: Update checkpoint every 100 blobs
- [ ] Manual trigger succeeds and completes within 4 hours
- [ ] Validation: Daily row counts match expected (spot-check 10 dates)
- [ ] Evidence: Pipeline run history + ADX validation query results

**Effort**: 5 points  
**Priority**: P1  
**Assigned To**: Data Engineer

---

## Epic 3: APIM Attribution & Telemetry

**Goal**: Capture cost attribution headers from APIM and correlate with Azure spend.  
**Business Value**: Enable chargeback/showback to consuming applications and cost centers.  
**Effort**: 13 points (Sprints 5-6)

### Feature 3.1: APIM Policy Configuration

**User Story**: As a FinOps analyst, I need to know which applications are driving Azure spend so I can allocate costs accurately.

#### Task 3.1.1: Implement APIM Cost Attribution Policy (M)
**Description**: Add base policy to inject/normalize `x-eva-costcenter`, `x-eva-caller-app`, `x-eva-environment` headers.

**Acceptance Criteria**:
- [ ] Policy added to "All APIs" base policy in Portal
- [ ] Inbound section extracts headers from JWT claims or request headers
- [ ] Default values applied for missing headers (UNKNOWN)
- [ ] Test request with curl includes header: `x-costcenter: TEST123`
- [ ] Policy XML exported and saved to repo: `infra/apim/base-policy.xml`
- [ ] Evidence: Screenshot of policy editor + test request with headers

**Effort**: 3 points  
**Priority**: P0  
**Assigned To**: API Developer

---

#### Task 3.1.2: Configure APIM Diagnostics to App Insights (S)
**Description**: Enable Application Insights logging for all APIs with 100% sampling.

**Acceptance Criteria**:
- [ ] Logger created: marco-sandbox-appinsights linked to APIM
- [ ] Diagnostics enabled: All APIs, verbosity=information, sampling=100%
- [ ] Custom dimensions captured: x-eva-costcenter, x-eva-caller-app, x-eva-environment
- [ ] Test request generates log entry in App Insights within 60 seconds
- [ ] KQL query validates: `requests | where customDimensions["x-eva-costcenter"] != ""`
- [ ] Evidence: App Insights query screenshot showing custom dimensions

**Effort**: 2 points  
**Priority**: P0  
**Assigned To**: DevOps Engineer

---

### Feature 3.2: Telemetry Ingestion to ADX

**User Story**: As a data engineer, I need APIM request logs in ADX to join with cost data by timestamp and resource.

#### Task 3.2.1: Create ADF Pipeline: ingest-apim-telemetry (L)
**Description**: Build pipeline to export App Insights logs and ingest into ADX `apim_usage` table.

**Acceptance Criteria**:
- [ ] Pipeline scheduled: Daily 3 AM UTC
- [ ] Data source: App Insights Analytics query (yesterday's requests)
- [ ] Sink: ADX table `apim_usage` with columns: Timestamp, ApiId, CallerApp, CostCenter, etc.
- [ ] First run succeeds and populates ADX: `apim_usage | count` > 0
- [ ] Evidence: Pipeline JSON + ADX query result showing sample rows

**Effort**: 5 points  
**Priority**: P0  
**Assigned To**: Data Engineer

---

#### Task 3.2.2: Validate Allocation Function (M)
**Description**: Test `AllocateCostByApp()` KQL function with sample data.

**Acceptance Criteria**:
- [ ] Sample data: 100 APIM requests, 10 cost records for APIM resource
- [ ] Function execution succeeds: `AllocateCostByApp() | take 10`
- [ ] Validation: Total AllocatedCost == Total APIM cost (within 1% tolerance)
- [ ] Results show per-app breakdown with RequestCount and AllocatedCost columns
- [ ] Evidence: ADX query result screenshot

**Effort**: 3 points  
**Priority**: P1  
**Assigned To**: Data Analyst

---

## Epic 4: Reporting & Visualization

**Goal**: Deploy Power BI reports and dashboards for executive cost visibility.  
**Business Value**: Enable self-service cost analytics and trend monitoring.  
**Effort**: 8 points (Sprint 7)

### Feature 4.1: Power BI Workspace Setup

**User Story**: As a FinOps manager, I need interactive dashboards to monitor spending trends and identify optimization opportunities.

#### Task 4.1.1: Create Power BI Workspace (XS)
**Description**: Provision shared workspace `FinOps Analytics` with Pro licensing.

**Acceptance Criteria**:
- [ ] Workspace created: `FinOps Analytics` (shared capacity or Premium)
- [ ] Members added: FinOps team (Contributor), Executives (Viewer)
- [ ] Evidence: Workspace members list screenshot

**Effort**: 1 point  
**Priority**: P1  
**Assigned To**: BI Administrator

---

#### Task 4.1.2: Deploy Cost Trend Dashboard (M)
**Description**: Create PBIX with ADX DirectQuery connection showing daily/monthly cost trends.

**Acceptance Criteria**:
- [ ] Data source: ADX cluster `marcofinopsadx`, database `finopsdb`, table `normalized_costs`
- [ ] Visuals: Line chart (90-day trend), cards (MTD spend, budget %), bar chart (top 10 RGs)
- [ ] Filters: Subscription, Date range, Resource Group
- [ ] Refresh: Auto (DirectQuery, no scheduled refresh needed)
- [ ] Published to workspace and pinned to dashboard
- [ ] Evidence: Dashboard screenshot + sample KQL queries used

**Effort**: 3 points  
**Priority**: P1  
**Assigned To**: BI Developer

---

#### Task 4.1.3: Deploy APIM Allocation Report (M)
**Description**: Create report showing cost allocation by caller app and cost center.

**Acceptance Criteria**:
- [ ] Data source: ADX function `AllocateCostByApp()`
- [ ] Visuals: Table (CallerApp, Cost, Requests), Pie chart (by CostCenter)
- [ ] Date range parameter: Last 30 days (default)
- [ ] Published to workspace
- [ ] Evidence: Report screenshot with sample allocation data

**Effort**: 3 points  
**Priority**: P1  
**Assigned To**: BI Developer

---

#### Task 4.1.4: Deploy Tag Compliance Report (S)
**Description**: Create report showing untagged resources and compliance percentage.

**Acceptance Criteria**:
- [ ] Data source: ADX table `normalized_costs`
- [ ] Visuals: Gauge (compliance %), table (untagged resources with cost)
- [ ] Filter: Date = Yesterday (latest full day)
- [ ] Published to workspace
- [ ] Evidence: Report screenshot showing compliance percentage

**Effort**: 2 points  
**Priority**: P2  
**Assigned To**: BI Developer

---

## Epic 5: Governance & Hardening

**Goal**: Enforce policies, enable private endpoints, and implement CI/CD for infrastructure.  
**Business Value**: Reduce security risk and improve compliance posture.  
**Effort**: 13 points (Sprints 8-9)

### Feature 5.1: Azure Policy Enforcement

**User Story**: As a security architect, I need to enforce tagging standards to prevent cost allocation gaps.

#### Task 5.1.1: Deploy Policy: Require CostCenter Tag (S)
**Description**: Create and assign custom policy that denies resource creation without CostCenter tag.

**Acceptance Criteria**:
- [ ] Policy definition JSON created: `require-costcenter-tag.json`
- [ ] Policy assigned to scope: `/subscriptions/.../resourceGroups/EsDAICoE-Sandbox`
- [ ] Test: Create resource without tag → Deployment fails with policy error
- [ ] Compliance scan shows non-compliant resources (if any)
- [ ] Evidence: Policy assignment + test deployment failure

**Effort**: 2 points  
**Priority**: P2  
**Assigned To**: Cloud Architect

---

### Feature 5.2: Private Endpoint Implementation

**User Story**: As a security engineer, I need private connectivity to storage and ADX to eliminate public internet exposure.

#### Task 5.2.1: Deploy VNet for FinOps Resources (M)
**Description**: Create VNet `vnet-finops-canadacentral` with private endpoint subnet.

**Acceptance Criteria**:
- [ ] VNet created: Address space 10.100.0.0/16
- [ ] Subnet: `subnet-privatelink` (10.100.1.0/24, private endpoint policies disabled)
- [ ] VNet peering (if needed): Connect to existing DevBox VNet
- [ ] Evidence: VNet properties screenshot

**Effort**: 3 points  
**Priority**: P2  
**Assigned To**: Network Engineer

---

#### Task 5.2.2: Enable Private Endpoint for Storage (M)
**Description**: Configure private endpoint for `marcosandboxfinopshub` blob service.

**Acceptance Criteria**:
- [ ] Private endpoint created: `pe-marcosandbox-blob`
- [ ] Private DNS zone: privatelink.blob.core.windows.net
- [ ] Storage firewall: Deny public access, allow VNet subnet only
- [ ] Test from DevBox: `az storage blob list` succeeds
- [ ] Test from public IP: Connection refused
- [ ] Evidence: Private endpoint status + network test results

**Effort**: 3 points  
**Priority**: P2  
**Assigned To**: Network Engineer

---

#### Task 5.2.3: Enable Private Endpoint for ADX (M)
**Description**: Configure private endpoint for `marcofinopsadx` cluster.

**Acceptance Criteria**:
- [ ] Private endpoint created: `pe-marcofinops-adx`
- [ ] Private DNS zone: privatelink.canadacentral.kusto.windows.net
- [ ] ADX public access: Disabled
- [ ] Test from DevBox: KQL query succeeds
- [ ] Evidence: Private endpoint status screenshot

**Effort**: 3 points  
**Priority**: P2  
**Assigned To**: Network Engineer

---

### Feature 5.3: CI/CD Automation

**User Story**: As a DevOps engineer, I need automated deployment pipelines to avoid manual errors and ensure consistency.

#### Task 5.3.1: Create GitHub Actions Workflow (S)
**Description**: Implement workflow to validate and deploy Bicep templates on PR/merge.

**Acceptance Criteria**:
- [ ] Workflow file: `.github/workflows/deploy-finops.yml`
- [ ] Triggers: PR to main (validate only), merge to main (validate + deploy)
- [ ] Jobs: Bicep build, ARM validation, deployment to EsDAICoE-Sandbox
- [ ] Secrets configured: AZURE_CREDENTIALS (service principal)
- [ ] Test run: PR triggers validation, merge triggers deployment
- [ ] Evidence: Workflow run history screenshot

**Effort**: 2 points  
**Priority**: P2  
**Assigned To**: DevOps Engineer

---

## Sprint Planning Summary

| Sprint | Epics/Features | Total Points | Key Deliverables |
|--------|----------------|--------------|------------------|
| Sprint 1-2 | Epic 1 (Foundation) | 13 | Storage hierarchy, Event Grid wired |
| Sprint 3-4 | Epic 2 (Analytics) | 21 | ADX deployed, ingestion pipeline live |
| Sprint 5-6 | Epic 3 (Attribution) | 13 | APIM headers, telemetry in ADX |
| Sprint 7 | Epic 4 (Reporting) | 8 | Power BI dashboards published |
| Sprint 8-9 | Epic 5 (Governance) | 13 | Policies enforced, private endpoints enabled |
| **Total** | **5 Epics** | **68 points** | **Full FinOps Hubs implementation** |

**Velocity Assumption**: 15 points/sprint (2-week sprints)  
**Estimated Timeline**: 9 weeks (4.5 sprints)

---

## Success Metrics (KPIs)

| Metric | Target | Measured By |
|--------|--------|-------------|
| Cost Data Completeness | 100% (12 months backfilled) | ADX query: daily row counts |
| Ingestion Latency | <30 minutes (export → ADX) | ADF pipeline duration |
| APIM Attribution Coverage | >80% of requests have CostCenter | App Insights query: % with custom dimension |
| Tag Compliance | >90% of resources tagged | ADX query: untagged resource count |
| Cost Allocation Accuracy | ±5% (APIM allocated vs. actual) | Validation query comparing allocation to invoice |
| Power BI Query Performance | <3 seconds (for 90-day trend) | Power BI Performance Analyzer |

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-02-17 08:20 AM ET | Marco Presta | Initial ADO-ready backlog with epics, features, and tasks |

---

**Document Status**: Ready for sprint planning  
**Next Review**: Sprint 0 planning session (2026-02-20)
