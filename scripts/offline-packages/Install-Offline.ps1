#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Azure SDK packages from offline cache
#>

$ErrorActionPreference = "Stop"

Write-Host "
[INFO] Installing Azure SDK packages from offline cache..." -ForegroundColor Yellow

try {
    # Install packages
    pip install --no-index --find-links . `
        azure-mgmt-costmanagement `
        azure-mgmt-resource `
        azure-identity `
        pandas

    if ($LASTEXITCODE -eq 0) {
        Write-Host "
[PASS] Installation complete!" -ForegroundColor Green
        Write-Host "
[INFO] Run validation: python ..\scripts\test_setup.py" -ForegroundColor Cyan
    } else {
        Write-Host "
[FAIL] Installation failed" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "
[FAIL] Error: $_" -ForegroundColor Red
    exit 1
}
