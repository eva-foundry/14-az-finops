# patch-tags-env-sec.ps1
# Two targeted passes on all marco* resources in EsDAICoE-Sandbox (EsDAICoESub):
#   Pass 1 — Normalize environment → "Dev" (merge: adds if missing, overwrites if dev/sandbox/etc.)
#   Pass 2 — Add sec_classification=Protected-A on data-tier resources
# Skips: CPC DevBox NIC (no rights), EsPAICoESub (no resources), managed RG resources

$sub     = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
$ok = 0; $skip = 0

function Invoke-TagMerge($id, $label, [string[]]$tags) {
    $result = az tag update --resource-id $id --operation Merge --tags @tags `
        --subscription $sub --output none 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK]   $label  +[$($tags -join ', ')]" -ForegroundColor Green
        $script:ok++
    } else {
        Write-Host "  [SKIP] $label" -ForegroundColor Yellow
        $script:skip++
    }
}

# ── Discover all marco* resources ─────────────────────────────────────────────
$resources = az resource list --subscription $sub `
    --query "[?contains(name,'marco') || contains(name,'Marco')].{id:id, name:name, rg:resourceGroup}" `
    -o json | ConvertFrom-Json

# Filter out the DevBox NIC (NI_ RG — no rights) and managed App Insights RG
$ownedRGs = @("EsDAICoE-Sandbox","esdaicoe-sandbox")
$resources = $resources | Where-Object {
    $_.rg -in $ownedRGs -or $_.resourceGroup -in $ownedRGs
} | Where-Object {
    $_.name -notmatch '^CPC-marco'  # DevBox NIC
}

Write-Host "`n[PASS 1] Normalize environment=Dev on $($resources.Count) resources" -ForegroundColor Cyan
foreach ($r in $resources) {
    Invoke-TagMerge $r.id $r.name @("environment=Dev")
}

# ── RG itself ─────────────────────────────────────────────────────────────────
$rgId = "/subscriptions/$sub/resourceGroups/EsDAICoE-Sandbox"
Invoke-TagMerge $rgId "EsDAICoE-Sandbox (RG)" @("environment=Dev")

# ── mi-finops-adf managed identity ───────────────────────────────────────────
$miId = az identity show --name "mi-finops-adf" --resource-group "EsDAICoE-Sandbox" `
    --subscription $sub --query id -o tsv 2>$null
if ($miId) { Invoke-TagMerge $miId "mi-finops-adf" @("environment=Dev") }

# ── PASS 2: sec_classification=Protected-A on data-tier resources ─────────────
Write-Host "`n[PASS 2] sec_classification=Protected-A on data-tier resources" -ForegroundColor Cyan

# Resources that store, move, or process cost/financial data
$dataTier = @(
    @{ name="marcosandboxfinopshub";   type="Microsoft.Storage/storageAccounts"  },
    @{ name="marcofinopsadx";          type="Microsoft.Kusto/clusters"            },
    @{ name="marco-sandbox-finops-adf";type="Microsoft.DataFactory/factories"     },
    @{ name="marco-finops-evhns";      type="Microsoft.EventHub/namespaces"       },
    @{ name="marcosandkv20260203";     type="Microsoft.KeyVault/vaults"           },
    @{ name="marco-sandbox-appinsights";type="Microsoft.Insights/components"      }
)

foreach ($d in $dataTier) {
    $r = $resources | Where-Object { $_.name -eq $d.name } | Select-Object -First 1
    if ($r) {
        Invoke-TagMerge $r.id $r.name @("sec_classification=Protected-A")
    } else {
        Write-Host "  [MISS] $($d.name) not found in resource list" -ForegroundColor DarkYellow
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Write-Host "  Tagged OK : $ok" -ForegroundColor Green
Write-Host "  Skipped   : $skip" -ForegroundColor Yellow
Write-Host ""
Write-Host "Pass 1: environment=Dev (all marco* in EsDAICoE-Sandbox)" -ForegroundColor DarkGray
Write-Host "Pass 2: sec_classification=Protected-A (data-tier: storage/ADX/ADF/evhns/kv/appinsights)" -ForegroundColor DarkGray
