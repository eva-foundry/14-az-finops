#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Download and decompress all monthly exports for EsPAICoESub (Production)

.DESCRIPTION
    Downloads Cost Management exports from blob storage, decompresses them,
    and optionally combines into single dataset for Power BI analysis.

.PARAMETER OutputDir
    Output directory for downloaded files (default: output\EsPAICoESub-historical)

.PARAMETER CombineFiles
    Combine all monthly CSVs into single file

.PARAMETER SkipDownload
    Skip download, only combine existing files

.EXAMPLE
    .\Download-Monthly-Exports-EsPAICoESub.ps1
    .\Download-Monthly-Exports-EsPAICoESub.ps1 -CombineFiles
    .\Download-Monthly-Exports-EsPAICoESub.ps1 -SkipDownload -CombineFiles

.NOTES
    Author: Marco Presta
    Date: 2026-02-17
    Prerequisites: Exports must be completed (check Portal export history)
#>

[CmdletBinding()]
param(
    [string]$OutputDir = "I:\eva-foundation\14-az-finops\output\EsPAICoESub-historical",
    [switch]$CombineFiles,
    [switch]$SkipDownload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Configuration
$storageAccount = "marcosandboxfinopshub"
$container = "costs"
$subscriptionName = "EsPAICoESub"

# Monthly export names
$exportMonths = @(
    "2025-02", "2025-03", "2025-04", "2025-05", "2025-06", "2025-07",
    "2025-08", "2025-09", "2025-10", "2025-11", "2025-12", "2026-01"
)

Write-Host "[INFO] EsPAICoESub Monthly Export Download & Processing" -ForegroundColor Cyan
Write-Host "[INFO] Storage: $storageAccount/$container"
Write-Host "[INFO] Output: $OutputDir"
Write-Host ""

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
    Write-Host "[INFO] Created output directory: $OutputDir" -ForegroundColor Green
}

# Check authentication
$currentAccount = az account show 2>$null | ConvertFrom-Json
if (-not $currentAccount) {
    Write-Host "[FAIL] Not logged into Azure CLI. Run: az login" -ForegroundColor Red
    exit 1
}

Write-Host "[PASS] Authenticated as: $($currentAccount.user.name)" -ForegroundColor Green
Write-Host ""

# Download exports
$downloadResults = @()

if (-not $SkipDownload) {
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "DOWNLOADING MONTHLY EXPORTS" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($month in $exportMonths) {
        Write-Host "[INFO] Processing $subscriptionName-$month..." -ForegroundColor Yellow
        
        # List blobs for this export
        $prefix = "$subscriptionName/$subscriptionName-$month/"
        $blobs = az storage blob list `
            --account-name $storageAccount `
            --container-name $container `
            --prefix $prefix `
            --auth-mode login `
            --query "[?ends_with(name, '.csv.gz')].{name:name, size:properties.contentLength}" `
            --output json 2>$null | ConvertFrom-Json
        
        if (-not $blobs -or $blobs.Count -eq 0) {
            Write-Host "[WARN] No export file found for $month - may still be running" -ForegroundColor Yellow
            $downloadResults += [PSCustomObject]@{
                Month = $month
                Status = "Not Found"
                SizeMB = 0
                Rows = 0
                FilePath = "N/A"
            }
            Write-Host ""
            continue
        }
        
        # Download .gz file
        $blobName = $blobs[0].name
        $gzFile = Join-Path $OutputDir "$subscriptionName-$month.csv.gz"
        $csvFile = Join-Path $OutputDir "$subscriptionName-$month.csv"
        
        Write-Host "[INFO] Downloading $([math]::Round($blobs[0].size/1MB, 2)) MB..."
        
        az storage blob download `
            --account-name $storageAccount `
            --container-name $container `
            --name $blobName `
            --file $gzFile `
            --auth-mode login `
            --no-progress `
            --output none 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[FAIL] Download failed" -ForegroundColor Red
            Write-Host ""
            continue
        }
        
        Write-Host "[PASS] Downloaded successfully" -ForegroundColor Green
        
        # Decompress
        Write-Host "[INFO] Decompressing..."
        try {
            $inStream = [System.IO.File]::OpenRead($gzFile)
            $gzStream = New-Object System.IO.Compression.GZipStream($inStream, [System.IO.Compression.CompressionMode]::Decompress)
            $outStream = [System.IO.File]::Create($csvFile)
            $gzStream.CopyTo($outStream)
            $outStream.Close()
            $gzStream.Close()
            $inStream.Close()
            
            # Get stats
            $fileInfo = Get-Item $csvFile
            $lineCount = (Get-Content $csvFile | Measure-Object -Line).Lines
            
            Write-Host "[PASS] Decompressed: $([math]::Round($fileInfo.Length/1MB, 2)) MB, $($lineCount - 1) data rows" -ForegroundColor Green
            
            $downloadResults += [PSCustomObject]@{
                Month = $month
                Status = "Success"
                SizeMB = [math]::Round($fileInfo.Length/1MB, 2)
                Rows = $lineCount - 1
                FilePath = $csvFile
            }
            
            # Remove .gz to save space
            Remove-Item $gzFile -Force
            
        } catch {
            Write-Host "[FAIL] Decompression failed: $_" -ForegroundColor Red
            $downloadResults += [PSCustomObject]@{
                Month = $month
                Status = "Decompression Failed"
                SizeMB = 0
                Rows = 0
                FilePath = "N/A"
            }
        }
        
        Write-Host ""
    }
    
    # Download summary
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "DOWNLOAD SUMMARY" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    $downloadResults | Format-Table -AutoSize
    Write-Host ""
}

# Combine files
if ($CombineFiles) {
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "COMBINING FILES" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
    
    $csvFiles = Get-ChildItem -Path $OutputDir -Filter "$subscriptionName-*.csv" | Where-Object { $_.Name -notlike "*combined*" }
    
    if ($csvFiles.Count -eq 0) {
        Write-Host "[WARN] No CSV files found to combine" -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] Found $($csvFiles.Count) monthly CSV files"
        $combinedFile = Join-Path $OutputDir "$subscriptionName-combined-12months.csv"
        
        # Read header from first file
        $firstFile = $csvFiles | Sort-Object Name | Select-Object -First 1
        $header = Get-Content $firstFile.FullName -First 1
        
        Write-Host "[INFO] Writing header from $($firstFile.Name)..."
        $header | Out-File -FilePath $combinedFile -Encoding utf8
        
        # Append data from all files (skip headers)
        $totalRows = 0
        foreach ($file in ($csvFiles | Sort-Object Name)) {
            Write-Host "[INFO] Appending $($file.Name)..."
            $content = Get-Content $file.FullName | Select-Object -Skip 1
            $rowCount = ($content | Measure-Object).Count
            $totalRows += $rowCount
            $content | Out-File -FilePath $combinedFile -Encoding utf8 -Append
        }
        
        $combinedFileInfo = Get-Item $combinedFile
        Write-Host ""
        Write-Host "[PASS] Combined file created successfully" -ForegroundColor Green
        Write-Host "[INFO] File: $combinedFile"
        Write-Host "[INFO] Size: $([math]::Round($combinedFileInfo.Length/1MB, 2)) MB"
        Write-Host "[INFO] Total data rows: $totalRows"
        Write-Host ""
        
        # Column analysis
        Write-Host "[INFO] Analyzing column structure..."
        $headers = $header -split ','
        Write-Host "[INFO] Total columns: $($headers.Count)"
        Write-Host "[INFO] Key columns for Power BI:"
        $keyColumns = @('Date', 'CostInBillingCurrency', 'ResourceId', 'ResourceGroup', 'MeterCategory', 'Tags', 'SubscriptionName')
        foreach ($col in $keyColumns) {
            if ($headers -contains $col) {
                Write-Host "  [PASS] $col" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] $col (not found)" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "PROCESSING COMPLETE" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""
Write-Host "[INFO] Output directory: $OutputDir"
Write-Host "[INFO] Individual files: $($exportMonths.Count) monthly CSVs"
if ($CombineFiles -and (Test-Path (Join-Path $OutputDir "$subscriptionName-combined-12months.csv"))) {
    Write-Host "[INFO] Combined file: $subscriptionName-combined-12months.csv"
}
Write-Host ""
Write-Host "[INFO] Next steps:"
Write-Host "  1. Review data in output directory"
Write-Host "  2. Import into Power BI Desktop"
Write-Host "  3. Create dashboards for cost analysis"
Write-Host ""
Write-Host "[INFO] Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
