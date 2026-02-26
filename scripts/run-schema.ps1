# run-schema.ps1
# Phase 2 Task 2.1.2 - Deploy ADX schema by executing each KQL file via REST API
# Reads from scripts/kql/01-*.kql ... 09-*.kql (one command per file, no quoting issues)
#
# Usage:
#   .\run-schema.ps1                # run all blocks
#   .\run-schema.ps1 -Block 2       # run a specific block only (1-9)
#   .\run-schema.ps1 -WhatIf        # preview without executing

[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$Block = 0,
    [string]$ClusterUri = "https://marcofinopsadx.canadacentral.kusto.windows.net",
    [string]$Database   = "finopsdb",
    [string]$KqlDir     = "$PSScriptRoot\kql"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== ADX Schema Deployment ===" -ForegroundColor Cyan
Write-Host "Cluster : $ClusterUri"
Write-Host "Database: $Database"
Write-Host "KQL dir : $KqlDir"
Write-Host ""

# Acquire ADX bearer token
$token = az account get-access-token --resource "https://kusto.windows.net" --query accessToken -o tsv 2>&1
if ($LASTEXITCODE -ne 0) { throw "Token acquisition failed - run 'az login' first." }

function Invoke-KqlFile {
    param([string]$FilePath)

    $filename = Split-Path $FilePath -Leaf
    $num      = [int]($filename.Substring(0, 2))
    if ($Block -gt 0 -and $Block -ne $num) { return }

    $csl = Get-Content $FilePath -Raw -Encoding UTF8
    Write-Host "[$num] $filename" -ForegroundColor Yellow

    if ($PSCmdlet.ShouldProcess($filename, "POST to ADX mgmt")) {
        # Build body object and serialize - PowerShell handles all escaping
        $bodyObj = [ordered]@{ db = $Database; csl = $csl }
        $tmpJson = "$env:TEMP\kql_block_$num.json"
        $bodyObj | ConvertTo-Json -Depth 3 -Compress | Set-Content $tmpJson -Encoding UTF8

        $result = az rest --method POST `
            --url "$ClusterUri/v1/rest/mgmt" `
            --headers "Authorization=Bearer $token" "Content-Type=application/json; charset=utf-8" `
            --body "@$tmpJson" `
            -o json 2>&1

        Remove-Item $tmpJson -Force -ErrorAction SilentlyContinue

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [FAIL] $result" -ForegroundColor Red
            throw "Block $num failed: $filename"
        }
        Write-Host "  [OK]" -ForegroundColor Green
    }
}

# Execute each numbered KQL file in order
$files = Get-ChildItem -Path $KqlDir -Filter "*.kql" | Sort-Object Name
if ($files.Count -eq 0) { throw "No .kql files found in $KqlDir" }

foreach ($f in $files) {
    Invoke-KqlFile -FilePath $f.FullName
}

# Verification
if ($Block -eq 0 -or $Block -eq 99) {
    Write-Host ""
    Write-Host "=== Verification ===" -ForegroundColor Cyan

    $verifyBodyObj = [ordered]@{ db = $Database; csl = ".show tables | where TableName in ('raw_costs', 'apim_usage') | project TableName" }
    $tmpVerify = "$env:TEMP\kql_verify.json"
    $verifyBodyObj | ConvertTo-Json -Depth 3 -Compress | Set-Content $tmpVerify -Encoding UTF8

    $verify = az rest --method POST `
        --url "$ClusterUri/v1/rest/mgmt" `
        --headers "Authorization=Bearer $token" "Content-Type=application/json; charset=utf-8" `
        --body "@$tmpVerify" `
        --query "Tables[0].Rows" `
        -o json 2>&1
    Remove-Item $tmpVerify -Force -ErrorAction SilentlyContinue

    Write-Host "Tables found: $verify"
    Write-Host ""
    Write-Host "[DONE] Schema deployed." -ForegroundColor Green
    Write-Host "Confirm in ADX Web UI (finopsdb context):"
    Write-Host "  .show table raw_costs ingestion csv mappings"
    Write-Host "  .show materialized-views | where Name == 'normalized_costs'"
    Write-Host "  .show functions | where Name == 'AllocateCostByApp'"
    Write-Host "  https://dataexplorer.azure.com/clusters/marcofinopsadx.canadacentral/databases/finopsdb"
}
