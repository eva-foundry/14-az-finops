# DATA MODEL QUERY REFERENCE: Project 14 (Azure FinOps)

**Quick Commands for Understanding How Project 14 Fits in Data Model**

---

## Bootstrap: Check Data Model Health

```powershell
# Is the data model API running?
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"

# Health check
$h = Invoke-RestMethod "$base/health" -ErrorAction SilentlyContinue
if ($h) {
    Write-Host "[OK] Store: $($h.store), Status: $($h.status), Version: $($h.version)"
} else {
    Write-Host "[FALLBACK] Try local dev: http://localhost:8010"
    $base = "http://localhost:8010"
    $h = Invoke-RestMethod "$base/health"
}

# View full API documentation
$guide = Invoke-RestMethod "$base/model/agent-guide"
$guide.model_summary  # See all 32 layers
```

---

## Query 1: What Resources Does Project 14 (finops-hub) Use?

```powershell
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"

# Get all infrastructure records for finops-hub service
$p14_resources = Invoke-RestMethod "$base/model/infrastructure/?service=finops-hub"

# Display results
$p14_resources | Select-Object id, type, location, status, is_active | Format-Table -AutoSize

# EXPECTED OUTPUT (if registered):
# id                              type                    location        status  is_active
# ----                            ----                    --------        ------  --------
# marcofinopsadx                  data_explorer_cluster   canadacentral   active  True
# marco-sandbox-finops-adf        data_factory            canadacentral   active  True
# marcosandboxfinopshub           blob_storage            canadacentral   active  True
```

---

## Query 2: What Breaks If a Resource Fails?

```powershell
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"

# Impact analysis: what depends on marcofinopsadx?
$impact = Invoke-RestMethod "$base/model/impact/?resource=marcofinopsadx" `
    -ErrorAction SilentlyContinue

if ($impact) {
    Write-Host "=== IMPACT ANALYSIS: marcofinopsadx ==="
    Write-Host "Dependent services: $($impact.dependent_services -join ', ')"
    Write-Host "Affected endpoints: $($impact.affected_endpoints -join ', ')"
    Write-Host "Blocked stories: $($impact.blocked_stories -join ', ')"
} else {
    Write-Host "WARN: Impact queries may not be available on this model version"
}
```

---

## Query 3: Register Project 14 Resources (If Not Already Done)

**Run one PUT call per resource**:

```powershell
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"

# Resource 1: ADX Cluster
$adx = @{
    id = "marcofinopsadx"
    type = "data_explorer_cluster"
    azure_resource_name = "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Kusto/clusters/marcofinopsadx"
    service = "finops-hub"
    resource_group = "EsDAICoE-Sandbox"
    location = "canadacentral"
    status = "active"
    is_active = $true
    provision_order = 1
}
$body = $adx | ConvertTo-Json -Depth 10
$resp = Invoke-RestMethod "$base/model/infrastructure/marcofinopsadx" `
    -Method PUT `
    -ContentType "application/json" `
    -Body $body `
    -Headers @{"X-Actor"="agent:copilot"} `
    -ErrorAction SilentlyContinue
if ($resp) {
    Write-Host "[OK] marcofinopsadx registered | row_version: $($resp.row_version)"
} else {
    Write-Host "[FAIL] Could not register marcofinopsadx"
}

# Resource 2: ADF Pipeline
$adf = @{
    id = "marco-sandbox-finops-adf"
    type = "data_factory"
    azure_resource_name = "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.DataFactory/factories/marco-sandbox-finops-adf"
    service = "finops-hub"
    resource_group = "EsDAICoE-Sandbox"
    location = "canadacentral"
    status = "active"
    is_active = $true
    provision_order = 2
}
$body = $adf | ConvertTo-Json -Depth 10
$resp = Invoke-RestMethod "$base/model/infrastructure/marco-sandbox-finops-adf" `
    -Method PUT `
    -ContentType "application/json" `
    -Body $body `
    -Headers @{"X-Actor"="agent:copilot"} `
    -ErrorAction SilentlyContinue
if ($resp) {
    Write-Host "[OK] marco-sandbox-finops-adf registered | row_version: $($resp.row_version)"
}

# Resource 3: ADLS Storage
$storage = @{
    id = "marcosandboxfinopshub"
    type = "blob_storage"
    azure_resource_name = "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/EsDAICoE-Sandbox/providers/Microsoft.Storage/storageAccounts/marcosandboxfinopshub"
    service = "finops-hub"
    resource_group = "EsDAICoE-Sandbox"
    location = "canadacentral"
    status = "active"
    is_active = $true
    provision_order = 0
}
$body = $storage | ConvertTo-Json -Depth 10
$resp = Invoke-RestMethod "$base/model/infrastructure/marcosandboxfinopshub" `
    -Method PUT `
    -ContentType "application/json" `
    -Body $body `
    -Headers @{"X-Actor"="agent:copilot"} `
    -ErrorAction SilentlyContinue
if ($resp) {
    Write-Host "[OK] marcosandboxfinopshub registered | row_version: $($resp.row_version)"
}

# Commit changes
Write-Host "`nCommitting data model changes..."
$commit = Invoke-RestMethod "$base/model/admin/commit" `
    -Method POST `
    -Headers @{"Authorization"="Bearer dev-admin"} `
    -ErrorAction SilentlyContinue
if ($commit) {
    Write-Host "[INFO] Commit status: $($commit.status)"
    Write-Host "[INFO] Violations: $($commit.violation_count)"
}
```

---

## Query 4: List All Projects & Their Resources

```powershell
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"

# Get all infrastructure records
$all_infra = Invoke-RestMethod "$base/model/infrastructure/"

# Group by service
$grouped = $all_infra | Group-Object -Property service

Write-Host "=== INFRASTRUCTURE BY SERVICE ==="
foreach ($group in $grouped) {
    Write-Host "`n[$($group.Name)]"
    $group.Group | Select-Object id, type | Format-Table -AutoSize
}
```

---

## Query 5: Verify Project 14 Data Quality

```powershell
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"

# Get summary of all layers
$summary = Invoke-RestMethod "$base/model/agent-summary"

Write-Host "=== DATA MODEL SUMMARY ==="
Write-Host "Total objects: $($summary.total)"
Write-Host "Store reachable: $($summary.store_reachable)"
Write-Host "Model version: $($summary.version)"
Write-Host "`n=== LAYER COUNTS ==="
$summary.layers | Select-Object layer, count | Format-Table -AutoSize
```

---

## Query 6: Check WBS (Work Breakdown Structure) for Project 14

```powershell
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"

# Get all WBS stories for project 14
$wbs = Invoke-RestMethod "$base/model/wbs/" -ErrorAction SilentlyContinue

# Filter for F14-* stories (project 14 uses F14 prefix from PLAN.md)
$p14_stories = $wbs | Where-Object { $_.id -like "F14-*" }

if ($p14_stories) {
    Write-Host "=== PROJECT 14 WBS STORIES ==="
    $p14_stories | Select-Object id, title, status, phase | Format-Table -AutoSize
} else {
    Write-Host "WARN: No F14-* stories found; may need seeding from PLAN.md"
}
```

---

## Query 7: Evidence Audit Trail (Phase Completions)

```powershell
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"

# Get evidence records for completed stories
# (Evidence Layer = immutable audit trail of story completions)
$evidence = Invoke-RestMethod "$base/model/evidence/?sprint_id=F14*" `
    -ErrorAction SilentlyContinue

if ($evidence) {
    Write-Host "=== PROJECT 14 EVIDENCE (Phase Completions) ==="
    $evidence | Select-Object correlation_id, phase, completed_at | Format-Table -AutoSize
} else {
    Write-Host "Note: Evidence queries may not be available yet on your model version"
}
```

---

## Data Model Troubleshooting

### Problem: Data Model Unreachable

```powershell
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"
$h = Invoke-RestMethod "$base/health" -ErrorAction SilentlyContinue

if (-not $h) {
    Write-Host "[FALLBACK] Trying local dev on port 8010..."
    $base = "http://localhost:8010"
    $h = Invoke-RestMethod "$base/health" -ErrorAction SilentlyContinue
    
    if (-not $h) {
        Write-Host "[ACTION] Start local server:"
        Write-Host "  cd C:\AICOE\eva-foundry\37-data-model"
        Write-Host "  python -m uvicorn api.server:app --port 8010 --reload"
        exit
    }
}
Write-Host "[OK] Data model is healthy"
```

### Problem: Infrastructure Query Returns Empty

```powershell
$base = "https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io"
$infra = Invoke-RestMethod "$base/model/infrastructure/"

if ($infra.Count -eq 0) {
    Write-Host "[WARN] Infrastructure layer is empty"
    Write-Host "[ACTION] Register resources using PUT /model/infrastructure/{id} (see Query 3)"
} else {
    Write-Host "[OK] Found $($infra.Count) infrastructure records"
}
```

### Problem: Row Version Conflict on PUT

```powershell
# Always fetch current row_version BEFORE updating
$ep = Invoke-RestMethod "$base/model/infrastructure/marcofinopsadx"
$prev_rv = $ep.row_version  # MUST capture this

# Update only domain fields, EXCLUDE audit columns
$ep_update = @{
    id = $ep.id
    service = $ep.service
    status = "deprecated"  # Example: changing status
    is_active = $false
}

$body = $ep_update | ConvertTo-Json -Depth 10
$resp = Invoke-RestMethod "$base/model/infrastructure/marcofinopsadx" `
    -Method PUT `
    -ContentType "application/json" `
    -Body $body `
    -Headers @{"X-Actor"="agent:copilot"}

# Verify: new row_version should = prev_rv + 1
if ($resp.row_version -eq $prev_rv + 1) {
    Write-Host "[OK] Update succeeded"
}
```

---

## Reference: Data Model Layers

```
Layer 1:  projects         -- 54 repositories (31-eva-faces, 33-eva-brain-v2, etc.)
Layer 2:  services         -- 15+ running services (data-model-api, eva-brain-api, etc.)
Layer 3:  endpoints        -- 290+ HTTP routes (/v1/chat, /api/costs, etc.)
Layer 4:  screens          -- 30+ React components (AdminFaceApp, ChatPage, etc.)
Layer 5:  components       -- Reusable UI/logic componentsLibraries
Layer 6:  infrastructure   -- Azure resources (Cosmos, ADX, ADF, App Service, etc.)
Layer 7:  containers       -- Cosmos DB containers (jobs, profiles, evidence, etc.)
Layer 8:  hooks            -- React hook functions (useActingSession, useRole, etc.)
Layer 9:  agents           -- AI agents (ado_plane, azure_plane, github_plane, etc.)
Layer 10: wbs              -- Work breakdown structure (F14-01, F14-02, etc.)
Layer 11: sprints           -- Sprint manifests (SPRINT_MANIFEST.json files)
...
Layer 31: evidence         -- Immutable proof of completion (audit trail)
Layer 32: [other meta layers]
```

**Query any layer**: `GET /model/{layer}/?{filters}`

---

## Golden Rules

1. **One HTTP call beats 10 file reads**
   - Use data model API, not grep/file_search
   - Query is 100x faster + more accurate

2. **Always capture `row_version` before PUT**
   - Get current object
   - Update domain fields only
   - Exclude audit columns (layer, created_by, created_at, etc.)

3. **PUT full object with `-Depth 10`**
   - Nested schemas (request_schema, response_schema) truncate at Depth 5
   - Always use `-Depth 10`

4. **X-Actor header for accountability**
   - All PUT/POST include `-Headers @{"X-Actor"="agent:copilot"}`
   - Audit trail tracks who made changes

5. **Commit after batch changes**
   - `POST /model/admin/commit` after multiple PUTs
   - Validates cross-references + exports Cosmos data

---

**Generated**: March 3, 2026  
**For Project**: 14-az-finops (Azure FinOps)  
**Data Model**: https://marco-eva-data-model.livelyflower-7990bc7b.canadacentral.azurecontainerapps.io

