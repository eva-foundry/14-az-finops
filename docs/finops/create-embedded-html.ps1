# Create self-contained HTML with Base64-embedded images for SharePoint

$htmlPath = "i:\eva-foundation\14-az-finops\docs\finops\02-target-architecture-sharepoint.html"
$outputPath = "i:\eva-foundation\14-az-finops\docs\finops\02-target-architecture-embedded.html"

$img1Path = "i:\eva-foundation\14-az-finops\docs\finops\02-target-architecture-figure1.png"
$img2Path = "i:\eva-foundation\14-az-finops\docs\finops\02-target-architecture-figure2.png"
$img3Path = "i:\eva-foundation\14-az-finops\docs\finops\02-target-architecture-figure3.png"

Write-Host "Converting images to Base64..."
$img1Base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($img1Path))
$img2Base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($img2Path))
$img3Base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($img3Path))

Write-Host "Figure 1: $($img1Base64.Length) chars"
Write-Host "Figure 2: $($img2Base64.Length) chars"
Write-Host "Figure 3: $($img3Base64.Length) chars"

Write-Host "Reading HTML template..."
$html = Get-Content $htmlPath -Raw

Write-Host "Replacing image references with Base64 data URIs..."
$html = $html -replace 'src="02-target-architecture-figure1\.png"', "src=`"data:image/png;base64,$img1Base64`""
$html = $html -replace 'src="02-target-architecture-figure2\.png"', "src=`"data:image/png;base64,$img2Base64`""
$html = $html -replace 'src="02-target-architecture-figure3\.png"', "src=`"data:image/png;base64,$img3Base64`""

Write-Host "Saving embedded HTML..."
$html | Set-Content $outputPath -Encoding UTF8

Write-Host "Done! Created: $outputPath"
Write-Host "File size: $((Get-Item $outputPath).Length / 1MB) MB"
