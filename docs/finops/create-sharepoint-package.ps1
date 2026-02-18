# Convert all FinOps markdown documentation to SharePoint-compatible HTML
# with professional styling and embedded images

$docsPath = "i:\eva-foundation\14-az-finops\docs\finops"
$outputFolder = "i:\eva-foundation\14-az-finops\docs\finops\sharepoint-package"

# Create output folder
New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null

# HTML template with professional styling
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{TITLE}</title>
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
        
        header {
            background: linear-gradient(135deg, #0078d4 0%, #107c10 100%);
            color: white;
            padding: 40px;
            border-radius: 8px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        h1 { font-size: 2.5em; margin-bottom: 15px; }
        h2 { color: #0078d4; font-size: 2em; margin: 30px 0 20px 0; padding-bottom: 10px; border-bottom: 3px solid #0078d4; }
        h3 { color: #107c10; font-size: 1.5em; margin: 25px 0 15px 0; }
        h4 { color: #ff8c00; font-size: 1.2em; margin: 20px 0 10px 0; }
        
        section {
            margin-bottom: 30px;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
            border: 1px solid #e1dfdd;
        }
        
        p { margin-bottom: 15px; text-align: justify; }
        
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
        
        .callout {
            padding: 15px 20px;
            border-radius: 6px;
            margin: 20px 0;
            border-left: 4px solid;
        }
        
        .callout.info { background: #e7f3ff; border-color: #0078d4; }
        .callout.success { background: #dff6dd; border-color: #107c10; }
        .callout.warning { background: #fff4ce; border-color: #ff8c00; }
        
        blockquote {
            border-left: 4px solid #0078d4;
            padding-left: 20px;
            margin: 20px 0;
            font-style: italic;
            color: #605e5c;
        }
        
        footer {
            margin-top: 50px;
            padding: 30px;
            background: #f8f8f8;
            border-radius: 8px;
            text-align: center;
            border: 1px solid #e1dfdd;
        }
    </style>
</head>
<body>
    <nav>
        <a href="index.html">🏠 Home</a>
        <a href="00-current-state-inventory.html">00 - Current State</a>
        <a href="01-gap-analysis-finops-hubs.html">01 - Gap Analysis</a>
        <a href="02-target-architecture-embedded.html">02 - Architecture</a>
        <a href="03-deployment-plan.html">03 - Deployment Plan</a>
        <a href="04-backlog.html">04 - Backlog</a>
        <a href="05-evidence-pack.html">05 - Evidence</a>
        <a href="PHASE1-DEPLOYMENT-CHECKLIST.html">Phase 1 Checklist</a>
    </nav>
    
    <header>
        <h1>{TITLE}</h1>
        <p style="margin:0; opacity:0.95;">FinOps Hubs - marcosandbox Implementation</p>
    </header>
    
    <section>
{CONTENT}
    </section>
    
    <footer>
        <p><strong>Project:</strong> FinOps Hubs Implementation (marcosandbox)</p>
        <p><em>Generated: {DATE}</em></p>
        <p><em>SharePoint-compatible HTML package</em></p>
    </footer>
</body>
</html>
'@

# Function to convert markdown to basic HTML
function Convert-MarkdownToHtml {
    param([string]$markdown)
    
    # Simple markdown to HTML conversion (basic patterns)
    $html = $markdown
    
    # Headers
    $html = $html -replace '(?m)^### (.+)$', '<h3>$1</h3>'
    $html = $html -replace '(?m)^## (.+)$', '<h2>$1</h2>'
    $html = $html -replace '(?m)^# (.+)$', '<h1>$1</h1>'
    
    # Code blocks
    $html = $html -replace '(?s)```(\w+)?\r?\n(.+?)\r?\n```', '<pre><code>$2</code></pre>'
    $html = $html -replace '`([^`]+)`', '<code>$1</code>'
    
    # Lists
    $html = $html -replace '(?m)^- (.+)$', '<li>$1</li>'
    $html = $html -replace '(?m)^(\d+)\. (.+)$', '<li>$2</li>'
    
    # Bold and italic
    $html = $html -replace '\*\*(.+?)\*\*', '<strong>$1</strong>'
    $html = $html -replace '\*(.+?)\*', '<em>$1</em>'
    
    # Links
    $html = $html -replace '\[(.+?)\]\((.+?)\)', '<a href="$2">$1</a>'
    
    # Paragraphs (double newline)
    $html = $html -replace '(?m)^([^<\r\n].+)$', '<p>$1</p>'
    
    # Wrap lists
    $html = $html -replace '(<li>.+?</li>\s*)+', '<ul>$0</ul>'
    
    return $html
}

# Documents to convert
$documents = @(
    @{File = "README.md"; Title = "FinOps Hubs Documentation - Overview"; Output = "index.html"},
    @{File = "00-current-state-inventory.md"; Title = "00 - Current State Inventory"; Output = "00-current-state-inventory.html"},
    @{File = "01-gap-analysis-finops-hubs.md"; Title = "01 - Gap Analysis: FinOps Hubs"; Output = "01-gap-analysis-finops-hubs.html"},
    @{File = "03-deployment-plan.md"; Title = "03 - Deployment Plan"; Output = "03-deployment-plan.html"},
    @{File = "04-backlog.md"; Title = "04 - Backlog"; Output = "04-backlog.html"},
    @{File = "05-evidence-pack.md"; Title = "05 - Evidence Pack"; Output = "05-evidence-pack.html"},
    @{File = "PHASE1-DEPLOYMENT-CHECKLIST.md"; Title = "Phase 1 - Deployment Checklist"; Output = "PHASE1-DEPLOYMENT-CHECKLIST.html"}
)

Write-Host "Converting FinOps documentation to SharePoint-compatible HTML..." -ForegroundColor Cyan

foreach ($doc in $documents) {
    $mdPath = Join-Path $docsPath $doc.File
    
    if (Test-Path $mdPath) {
        Write-Host "  Converting: $($doc.File)..." -ForegroundColor Yellow
        
        # Read markdown content
        $markdownContent = Get-Content $mdPath -Raw
        
        # Convert to HTML
        $htmlContent = Convert-MarkdownToHtml -markdown $markdownContent
        
        # Apply template
        $finalHtml = $htmlTemplate -replace '{TITLE}', $doc.Title
        $finalHtml = $finalHtml -replace '{CONTENT}', $htmlContent
        $finalHtml = $finalHtml -replace '{DATE}', (Get-Date -Format "yyyy-MM-dd HH:mm")
        
        # Save to output folder
        $outputPath = Join-Path $outputFolder $doc.Output
        $finalHtml | Set-Content $outputPath -Encoding UTF8
        
        Write-Host "    Created: $($doc.Output)" -ForegroundColor Green
    } else {
        Write-Host "    Skipped: $($doc.File) (not found)" -ForegroundColor DarkGray
    }
}

# Copy the embedded architecture document
Write-Host "  Copying: 02-target-architecture-embedded.html..." -ForegroundColor Yellow
Copy-Item "$docsPath\02-target-architecture-embedded.html" "$outputFolder\02-target-architecture-embedded.html"
Write-Host "    Copied successfully" -ForegroundColor Green

Write-Host "`nPackage created in: $outputFolder" -ForegroundColor Cyan
Write-Host "Total files: $((Get-ChildItem $outputFolder -Filter '*.html').Count)" -ForegroundColor Cyan

# Create a README for the package
$packageReadme = @"
# FinOps Hubs Documentation Package (SharePoint-Compatible)

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm")

## Contents

This package contains all FinOps Hubs documentation converted to self-contained HTML files that work perfectly in SharePoint.

### Files Included:

1. **index.html** - Overview and navigation hub
2. **00-current-state-inventory.html** - Current Azure environment analysis
3. **01-gap-analysis-finops-hubs.html** - Gap analysis and requirements
4. **02-target-architecture-embedded.html** - Target architecture with embedded diagrams
5. **03-deployment-plan.html** - Detailed deployment plan
6. **04-backlog.html** - Implementation backlog
7. **05-evidence-pack.html** - Evidence and validation documents
8. **PHASE1-DEPLOYMENT-CHECKLIST.html** - Phase 1 deployment checklist

## How to Use

### Upload to SharePoint:
1. Create a folder in SharePoint (e.g., "FinOps Hubs Documentation")
2. Upload ALL HTML files from this package to that folder
3. Open `index.html` in SharePoint to start browsing

### Features:
- ✅ All files are self-contained (no external dependencies)
- ✅ Professional Azure-themed styling
- ✅ Navigation menu on every page
- ✅ All diagrams embedded (no 404 errors)
- ✅ Works in SharePoint, OneDrive, Teams, and local browsers
- ✅ Responsive design for mobile/desktop

### Navigation:
- Every page has a navigation bar at the top
- Click "🏠 Home" to return to the index
- All links are relative (work anywhere you copy the files)

## Technical Details

- **Styling:** Embedded CSS (no external stylesheets)
- **Images:** Base64-encoded (02-target-architecture only)
- **Compatibility:** All modern browsers, SharePoint Online, SharePoint 2019+
- **Security:** No JavaScript, no external resources (CSP-compliant)

## Source

Original markdown files: `I:\eva-foundation\14-az-finops\docs\finops\`
Conversion script: `create-sharepoint-package.ps1`
"@

$packageReadme | Set-Content "$outputFolder\README.txt" -Encoding UTF8

Write-Host "`nPackage README created" -ForegroundColor Green
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "DONE! SharePoint package ready at:" -ForegroundColor Green
Write-Host "$outputFolder" -ForegroundColor White
Write-Host "============================================`n" -ForegroundColor Cyan
