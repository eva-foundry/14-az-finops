# inspect-tags-deep.ps1 - Fixed for Azure Cost Export tag format (no outer braces)
$csv = "$env:TEMP\sample_costs.csv"
if (-not (Test-Path $csv)) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $gz   = [System.IO.Compression.GZipStream]::new([System.IO.File]::OpenRead("$env:TEMP\sample_costs.csv.gz"), [System.IO.Compression.CompressionMode]::Decompress)
    $fout = [System.IO.FileStream]::new($csv, [System.IO.FileMode]::Create)
    $gz.CopyTo($fout); $fout.Close(); $gz.Close()
}

$keyValues = @{}
$rowCount  = 0
$noTag     = 0
$parseErr  = 0

Import-Csv -Path $csv | Select-Object -First 10000 | ForEach-Object {
    $rowCount++
    $raw = $_.Tags
    if ([string]::IsNullOrWhiteSpace($raw) -or $raw -eq '{}') { $noTag++; return }

    # Azure exports tags WITHOUT outer {} -- wrap them
    $json = $raw.Trim()
    if (-not $json.StartsWith('{')) { $json = "{$json}" }

    try {
        $obj = $json | ConvertFrom-Json -ErrorAction Stop
        $obj.PSObject.Properties | ForEach-Object {
            $k = $_.Name.ToLower().Trim()
            $v = ([string]$_.Value).Trim()
            if ($v.Length -gt 80) { $v = $v.Substring(0,80) + '...' }
            if (-not $keyValues.ContainsKey($k)) { $keyValues[$k] = @{} }
            if (-not $keyValues[$k].ContainsKey($v)) { $keyValues[$k][$v] = 0 }
            $keyValues[$k][$v]++
        }
    } catch { $parseErr++ }
}

$tagged = $rowCount - $noTag
Write-Host "=== DISCOVERY SUMMARY ==="
Write-Host "Rows sampled  : $rowCount"
Write-Host "Tagged rows   : $tagged ($([math]::Round($tagged*100/$rowCount,1))%)"
Write-Host "Parse errors  : $parseErr"
Write-Host "Distinct keys : $($keyValues.Count)"
Write-Host ""
Write-Host "=== PER-KEY VALUE DISTRIBUTION (coverage / distinct values) ==="
$keyValues.GetEnumerator() | Sort-Object { -($_.Value.Values | Measure-Object -Sum).Sum } | ForEach-Object {
    $k    = $_.Key
    $vals = $_.Value
    $tot  = ($vals.Values | Measure-Object -Sum).Sum
    $pct  = [math]::Round($tot*100/$tagged,1)
    $uniq = $vals.Count
    Write-Host ""
    Write-Host "--- [$k]  coverage=$pct%  rows=$tot  distinct=$uniq ---"
    $vals.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15 | ForEach-Object {
        Write-Host "    $($_.Value)x  `"$($_.Key)`""
    }
}
