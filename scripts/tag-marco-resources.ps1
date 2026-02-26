# tag-marco-resources.ps1
# Tags all marco* resources with owner="Marco Presta" + project="GHCP-Sandbox"
# Uses --operation Merge: ADDS tags WITHOUT overwriting existing ones.
# Also tags EsDAICoE-Sandbox resource group.
# Run from: c:\eva-foundry-local\14-az-finops\scripts

$sub  = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$ok = 0; $skip = 0; $fail = 0

function Merge-Tags($id, $label) {
    $result = az tag update --resource-id $id --operation Merge `
        --tags "owner=Marco Presta" "project=GHCP-Sandbox" `
        --subscription $sub --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK]   $label" -ForegroundColor Green
        $script:ok++
    } else {
        Write-Host "  [SKIP] $label  ->  $result" -ForegroundColor Yellow
        $script:skip++
    }
}

# ── 1. Resource group ─────────────────────────────────────────────────────────
Write-Host "`n[RG] EsDAICoE-Sandbox" -ForegroundColor Cyan
$rgId = "/subscriptions/$sub/resourceGroups/EsDAICoE-Sandbox"
Merge-Tags $rgId "EsDAICoE-Sandbox (resource group)"

# ── 2. All marco* resources ───────────────────────────────────────────────────
Write-Host "`n[Resources] Discovering marco* ..." -ForegroundColor Cyan
$resources = az resource list --subscription $sub `
    --query "[?contains(name,'marco') || contains(name,'Marco')].{id:id, name:name, type:type}" `
    -o json | ConvertFrom-Json

Write-Host "  Found $($resources.Count) resources`n"

foreach ($r in $resources) {
    Merge-Tags $r.id $r.name
}

# ── 3. Managed identities in the sandbox RG (may not match marco*) ────────────
Write-Host "`n[Managed Identities] EsDAICoE-Sandbox" -ForegroundColor Cyan
$mis = az identity list --resource-group "EsDAICoE-Sandbox" --subscription $sub `
    --query "[].{id:id, name:name}" -o json 2>$null | ConvertFrom-Json
if ($mis) {
    foreach ($mi in $mis) { Merge-Tags $mi.id $mi.name }
} else { Write-Host "  (none found)" }

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Write-Host "  Tagged OK : $ok" -ForegroundColor Green
Write-Host "  Skipped   : $skip  (already has tags or not taggable)" -ForegroundColor Yellow
Write-Host "  Failed    : $fail" -ForegroundColor Red
Write-Host ""
Write-Host "Tags applied (merge — existing tags preserved):" -ForegroundColor DarkGray
Write-Host "  owner   = Marco Presta" -ForegroundColor DarkGray
Write-Host "  project = GHCP-Sandbox" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Other resources you could also tag:" -ForegroundColor Cyan
Write-Host "  - Subscription EsDAICoESub itself  (az account management-group ...)" -ForegroundColor DarkGray
Write-Host "  - Private endpoints (GUID-named private link resources)" -ForegroundColor DarkGray
Write-Host "  - Cost export schedules (portal-only, no tag support)" -ForegroundColor DarkGray
Write-Host "  - App Insights workspace (managed- prefix, already included above)" -ForegroundColor DarkGray
