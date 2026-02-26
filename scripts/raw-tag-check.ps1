# raw-tag-check.ps1 - check raw CSV encoding of Tags field
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Decompress to a temp CSV
$outCsv = "$env:TEMP\sample_costs.csv"
$gz   = [System.IO.Compression.GZipStream]::new([System.IO.File]::OpenRead("$env:TEMP\sample_costs.csv.gz"), [System.IO.Compression.CompressionMode]::Decompress)
$fout = [System.IO.FileStream]::new($outCsv, [System.IO.FileMode]::Create)
$gz.CopyTo($fout)
$fout.Close(); $gz.Close()
Write-Host "Decompressed to $outCsv"

# Read 5 rows with proper CSV parsing
$rows = Import-Csv -Path $outCsv | Select-Object -First 5
Write-Host "=== RAW Tags field (5 rows) ==="
$rows | ForEach-Object -Begin {$i=1} -Process {
    Write-Host ""
    Write-Host "--- Row $i ---"
    Write-Host $_.Tags.Substring(0, [Math]::Min(300, $_.Tags.Length))
    $i++
}
