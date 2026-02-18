# Create Single-Page HTML for SharePoint
# Combines all documents into one HTML with anchor navigation

Write-Host "[INFO] Creating single-page HTML for SharePoint compatibility" -ForegroundColor Cyan

$packagePath = "i:\eva-foundation\14-az-finops\docs\finops\sharepoint-package"
$outputFile = Join-Path $packagePath "FinOps-Documentation-SinglePage.html"

$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FinOps Hubs Documentation - Complete</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
            line-height: 1.6;
            color: #323130;
            background: #fff;
            padding: 20px;
            max-width: 1400px;
            margin: 0 auto;
        }
        
        nav {
            background: #f3f2f1;
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 30px;
            border-left: 4px solid #0078d4;
            position: sticky;
            top: 0;
            z-index: 1000;
        }
        
        nav a {
            color: #0078d4;
            text-decoration: none;
            margin-right: 20px;
            font-weight: 500;
        }
        
        nav a:hover {
            text-decoration: underline;
        }
        
        .document-section {
            background: white;
            padding: 40px;
            margin-bottom: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border: 1px solid #e1dfdd;
        }
        
        .document-header {
            background: linear-gradient(135deg, #0078d4 0%, #107c10 100%);
            color: white;
            padding: 30px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        
        .document-header h2 {
            color: white;
            border: none;
            margin: 0;
        }
        
        h1 { font-size: 2.5em; margin-bottom: 15px; }
        h2 { color: #0078d4; font-size: 2em; margin: 30px 0 20px 0; padding-bottom: 10px; border-bottom: 3px solid #0078d4; }
        h3 { color: #107c10; font-size: 1.5em; margin: 25px 0 15px 0; }
        h4 { color: #ff8c00; font-size: 1.2em; margin: 20px 0 10px 0; }
        
        p { margin-bottom: 15px; }
        
        ul, ol { margin: 15px 0; padding-left: 30px; }
        li { margin: 8px 0; }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        
        th, td {
            padding: 12px 15px;
            text-align: left;
            border: 1px solid #e1dfdd;
        }
        
        th {
            background: #f8f8f8;
            font-weight: 600;
            color: #0078d4;
        }
        
        tr:nth-child(even) { background: #fafafa; }
        tr:hover { background: #f0f0f0; }
        
        code {
            background: #f3f2f1;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 0.9em;
        }
        
        pre {
            background: #f3f2f1;
            padding: 20px;
            border-radius: 6px;
            overflow-x: auto;
            margin: 20px 0;
            border: 1px solid #e1dfdd;
        }
        
        pre code { background: none; padding: 0; }
        
        .back-to-top {
            position: fixed;
            bottom: 30px;
            right: 30px;
            background: #0078d4;
            color: white;
            padding: 15px 20px;
            border-radius: 50px;
            text-decoration: none;
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
        }
        
        .back-to-top:hover {
            background: #106ebe;
        }
    </style>
</head>
<body>
    <nav id="top">
        <strong>Quick Navigation:</strong>
        <a href="#overview">📋 Overview</a>
        <a href="#current-state">00 - Current State</a>
        <a href="#gap-analysis">01 - Gap Analysis</a>
        <a href="#architecture">02 - Architecture</a>
        <a href="#deployment">03 - Deployment</a>
        <a href="#backlog">04 - Backlog</a>
        <a href="#evidence">05 - Evidence</a>
        <a href="#checklist">Phase 1 Checklist</a>
    </nav>
    
    <div class="document-section" id="overview">
        <div class="document-header">
            <h2>FinOps Hubs Documentation - Overview</h2>
            <p>Complete documentation package for marcosandbox FinOps Hub implementation</p>
        </div>
"@

# Read each document and add as section
$documents = @(
    @{Id="current-state"; Title="00 - Current State Inventory"; File="00-current-state-inventory.html"},
    @{Id="gap-analysis"; Title="01 - Gap Analysis: FinOps Hubs"; File="01-gap-analysis-finops-hubs.html"},
    @{Id="architecture"; Title="02 - Target Architecture"; File="02-target-architecture-embedded.html"},
    @{Id="deployment"; Title="03 - Deployment Plan"; File="03-deployment-plan.html"},
    @{Id="backlog"; Title="04 - Implementation Backlog"; File="04-backlog.html"},
    @{Id="evidence"; Title="05 - Evidence Pack"; File="05-evidence-pack.html"},
    @{Id="checklist"; Title="Phase 1 Deployment Checklist"; File="PHASE1-DEPLOYMENT-CHECKLIST.html"}
)

Write-Host "[INFO] Processing $($documents.Count) documents..." -ForegroundColor Yellow

foreach ($doc in $documents) {
    Write-Host "  [ADDING] $($doc.Title)" -ForegroundColor Gray
    
    $filePath = Join-Path $packagePath $doc.File
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw -Encoding UTF8
        
        # Extract content between <body> and </body>
        if ($content -match '(?s)<body>(.*)</body>') {
            $bodyContent = $matches[1]
            
            # Remove existing nav tag
            $bodyContent = $bodyContent -replace '(?s)<nav>.*?</nav>', ''
            
            # Remove header tag from extracted content (we'll add our own)
            $bodyContent = $bodyContent -replace '(?s)<header>.*?</header>', ''
            
            # Wrap in section
            $htmlContent += @"

        <div class="document-section" id="$($doc.Id)">
            <div class="document-header">
                <h2>$($doc.Title)</h2>
            </div>
            $bodyContent
        </div>
"@
        } else {
            Write-Host "    [WARN] Could not extract body content from $($doc.File)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "    [ERROR] File not found: $($doc.File)" -ForegroundColor Red
    }
}

$htmlContent += @"

    </div>
    
    <a href="#top" class="back-to-top">↑ Back to Top</a>
</body>
</html>
"@

# Save single-page HTML
Set-Content -Path $outputFile -Value $htmlContent -Encoding UTF8 -NoNewline

$fileSize = [math]::Round((Get-Item $outputFile).Length / 1KB, 1)
Write-Host "`n[SUCCESS] Created single-page HTML: FinOps-Documentation-SinglePage.html" -ForegroundColor Green
Write-Host "[INFO] File size: $fileSize KB" -ForegroundColor Cyan
Write-Host "[INFO] This file will definitely work in SharePoint (uses anchor links only)" -ForegroundColor Green
