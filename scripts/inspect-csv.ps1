Add-Type -AssemblyName System.IO.Compression.FileSystem
$gz     = [System.IO.Compression.GZipStream]::new([System.IO.File]::OpenRead("$env:TEMP\sample.csv.gz"), [System.IO.Compression.CompressionMode]::Decompress)
$reader = [System.IO.StreamReader]::new($gz, [System.Text.Encoding]::UTF8)
$header = $reader.ReadLine()
$row2   = $reader.ReadLine()
$reader.Close(); $gz.Close()

Write-Host "=== HEADER ($($header.Split(',').Count) raw tokens) ==="
$header.Split(',') | ForEach-Object -Begin { $i=0 } -Process { Write-Host "  [$i] $_"; $i++ }

Write-Host ""
Write-Host "=== ROW 2 (first 200 chars) ==="
Write-Host $row2.Substring(0, [Math]::Min(200, $row2.Length))
Write-Host "Row 2 raw token count (naive split): $($row2.Split(',').Count)"
