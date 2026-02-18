# SharePoint Package Navigation Test
# Tests all inter-document links to verify SharePoint compatibility
# Date: 2026-02-17

Write-Host "[INFO] SharePoint Package Navigation Test - Starting" -ForegroundColor Cyan
Write-Host "[INFO] Testing navigation links across all 8 HTML documents" -ForegroundColor Cyan
Write-Host ""

$packagePath = "i:\eva-foundation\14-az-finops\docs\finops\sharepoint-package"
$evidencePath = Join-Path $packagePath "test-evidence"

# Create evidence folder
if (-not (Test-Path $evidencePath)) {
    New-Item -ItemType Directory -Path $evidencePath | Out-Null
}

# Define all HTML files in the package
$htmlFiles = @(
    "index.html",
    "00-current-state-inventory.html",
    "01-gap-analysis-finops-hubs.html",
    "02-target-architecture-embedded.html",
    "03-deployment-plan.html",
    "04-backlog.html",
    "05-evidence-pack.html",
    "PHASE1-DEPLOYMENT-CHECKLIST.html"
)

# Navigation link patterns to test
$expectedLinks = @(
    "index.html",
    "00-current-state-inventory.html",
    "01-gap-analysis-finops-hubs.html",
    "02-target-architecture-embedded.html",
    "03-deployment-plan.html",
    "04-backlog.html",
    "05-evidence-pack.html",
    "PHASE1-DEPLOYMENT-CHECKLIST.html"
)

$testResults = @()

Write-Host "[TEST 1] Verify all HTML files exist" -ForegroundColor Yellow
foreach ($file in $htmlFiles) {
    $filePath = Join-Path $packagePath $file
    $exists = Test-Path $filePath
    
    $result = [PSCustomObject]@{
        Test = "File Existence"
        File = $file
        Status = if ($exists) { "PASS" } else { "FAIL" }
        Details = if ($exists) { "File exists" } else { "File not found" }
    }
    $testResults += $result
    
    $color = if ($exists) { "Green" } else { "Red" }
    Write-Host "  [$($result.Status)] $file" -ForegroundColor $color
}

Write-Host ""
Write-Host "[TEST 2] Verify navigation links in each file" -ForegroundColor Yellow
foreach ($file in $htmlFiles) {
    $filePath = Join-Path $packagePath $file
    if (-not (Test-Path $filePath)) { continue }
    
    $content = Get-Content $filePath -Raw
    $linksFound = 0
    
    foreach ($expectedLink in $expectedLinks) {
        if ($content -match "href=`"$expectedLink`"") {
            $linksFound++
        }
    }
    
    $result = [PSCustomObject]@{
        Test = "Navigation Links"
        File = $file
        Status = if ($linksFound -eq $expectedLinks.Count) { "PASS" } else { "WARN" }
        Details = "$linksFound of $($expectedLinks.Count) links found"
    }
    $testResults += $result
    
    $color = if ($linksFound -eq $expectedLinks.Count) { "Green" } else { "Yellow" }
    Write-Host "  [$($result.Status)] $file - $($result.Details)" -ForegroundColor $color
}

Write-Host ""
Write-Host "[TEST 3] Verify architecture diagrams embedded" -ForegroundColor Yellow
$archFile = Join-Path $packagePath "02-target-architecture-embedded.html"
$archContent = Get-Content $archFile -Raw
$base64ImgCount = ([regex]::Matches($archContent, 'src="data:image/png;base64')).Count

$result = [PSCustomObject]@{
    Test = "Diagram Embedding"
    File = "02-target-architecture-embedded.html"
    Status = if ($base64ImgCount -ge 3) { "PASS" } else { "FAIL" }
    Details = "$base64ImgCount Base64-encoded images found (expected: 3)"
}
$testResults += $result

$color = if ($base64ImgCount -ge 3) { "Green" } else { "Red" }
Write-Host "  [$($result.Status)] Architecture diagrams - $($result.Details)" -ForegroundColor $color

Write-Host ""
Write-Host "[TEST 4] Check file sizes (embedded content)" -ForegroundColor Yellow
foreach ($file in $htmlFiles) {
    $filePath = Join-Path $packagePath $file
    if (-not (Test-Path $filePath)) { continue }
    
    $size = (Get-Item $filePath).Length
    $sizeKB = [math]::Round($size / 1024, 1)
    
    # Architecture file should be large due to embedded images
    $expectedSizePASS = if ($file -eq "02-target-architecture-embedded.html") {
        $size -gt 300000  # Over 300KB indicates diagrams embedded
    } else {
        $size -gt 1000  # Regular HTML should be at least 1KB
    }
    
    $result = [PSCustomObject]@{
        Test = "File Size"
        File = $file
        Status = if ($expectedSizePASS) { "PASS" } else { "FAIL" }
        Details = "$sizeKB KB"
    }
    $testResults += $result
    
    $color = if ($expectedSizePASS) { "Green" } else { "Red" }
    Write-Host "  [$($result.Status)] $file - $($result.Details)" -ForegroundColor $color
}

# Export test results
Write-Host ""
Write-Host "[INFO] Exporting test results..." -ForegroundColor Cyan
$resultsFile = Join-Path $evidencePath "test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$testResults | Export-Csv -Path $resultsFile -NoTypeInformation

# Summary
$passCount = ($testResults | Where-Object Status -eq "PASS").Count
$failCount = ($testResults | Where-Object Status -eq "FAIL").Count
$warnCount = ($testResults | Where-Object Status -eq "WARN").Count
$totalCount = $testResults.Count

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "[PASS] $passCount tests passed" -ForegroundColor Green
Write-Host "[FAIL] $failCount tests failed" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "[WARN] $warnCount tests with warnings" -ForegroundColor $(if ($warnCount -gt 0) { "Yellow" } else { "Green" })
Write-Host "Total: $totalCount tests executed" -ForegroundColor White
Write-Host ""
Write-Host "Results saved to: $resultsFile" -ForegroundColor Cyan
Write-Host ""

# Next steps guidance
Write-Host "[NEXT STEPS]" -ForegroundColor Yellow
Write-Host "1. Open index.html in browser to test navigation manually" -ForegroundColor White
Write-Host "   Start-Process '$packagePath\index.html'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Test with HTTP server (simulates SharePoint)" -ForegroundColor White
Write-Host "   cd '$packagePath'" -ForegroundColor Gray
Write-Host "   python -m http.server 8000" -ForegroundColor Gray
Write-Host "   Start-Process 'http://localhost:8000/index.html'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Upload all 8 HTML files to SharePoint for final validation" -ForegroundColor White
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "[SUCCESS] Package is ready for SharePoint deployment!" -ForegroundColor Green
} else {
    Write-Host "[ACTION REQUIRED] Fix failed tests before SharePoint deployment" -ForegroundColor Red
}
