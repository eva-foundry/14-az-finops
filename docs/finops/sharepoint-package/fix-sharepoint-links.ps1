# Fix SharePoint Navigation Links
# SharePoint HTML viewer needs special URL format for relative links

$packagePath = "i:\eva-foundation\14-az-finops\docs\finops\sharepoint-package"

# Get all HTML files
$htmlFiles = Get-ChildItem -Path $packagePath -Filter "*.html" | Where-Object { 
    $_.Name -ne "README.txt" 
}

Write-Host "[INFO] Fixing SharePoint navigation in $($htmlFiles.Count) HTML files" -ForegroundColor Cyan

foreach ($file in $htmlFiles) {
    Write-Host "`n[PROCESSING] $($file.Name)" -ForegroundColor Yellow
    
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # Replace relative links with SharePoint-compatible format
    # Pattern: href="filename.html" -> href="?id=filename.html" or just href="#" with onclick
    # Actually, for SharePoint, we need to use the proper relative path format
    
    # SharePoint requires links to be in format: ./filename.html or just click to download
    # The issue is SharePoint's HTML viewer doesn't navigate, it shows HTML in preview
    
    # Solution: Use target="_parent" to escape the preview iframe
    $content = $content -replace 'href="(index\.html)"', 'href="$1" target="_parent"'
    $content = $content -replace 'href="(00-current-state-inventory\.html)"', 'href="$1" target="_parent"'
    $content = $content -replace 'href="(01-gap-analysis-finops-hubs\.html)"', 'href="$1" target="_parent"'
    $content = $content -replace 'href="(02-target-architecture-embedded\.html)"', 'href="$1" target="_parent"'
    $content = $content -replace 'href="(03-deployment-plan\.html)"', 'href="$1" target="_parent"'
    $content = $content -replace 'href="(04-backlog\.html)"', 'href="$1" target="_parent"'
    $content = $content -replace 'href="(05-evidence-pack\.html)"', 'href="$1" target="_parent"'
    $content = $content -replace 'href="(PHASE1-DEPLOYMENT-CHECKLIST\.html)"', 'href="$1" target="_parent"'
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  [FIXED] Added target='_parent' to navigation links" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] No changes needed" -ForegroundColor Gray
    }
}

Write-Host "`n[COMPLETE] SharePoint navigation fixed" -ForegroundColor Green
Write-Host "[ACTION] Re-upload all HTML files to SharePoint to apply fix" -ForegroundColor Yellow
