Add-Type -AssemblyName System.IO.Compression.FileSystem
$gz = [System.IO.Compression.GZipStream]::new([System.IO.File]::OpenRead("$env:TEMP\sample_costs.csv.gz"), [System.IO.Compression.CompressionMode]::Decompress)
$reader = [System.IO.StreamReader]::new($gz, [System.Text.Encoding]::UTF8)
$reader.ReadLine() | Out-Null  # skip header

$tagSamples = @{}
$tagKeyFreq = @{}
$rowCount = 0
$noTagCount = 0

while (-not $reader.EndOfStream -and $rowCount -lt 8000) {
    $line = $reader.ReadLine()
    $rowCount++
    $m = [regex]::Match($line, '^(?:(?:"(?:[^""]|"")*"|[^,])*,){21}("(?:[^""]|"")*"|[^,]*)')
    $tagVal = $m.Groups[1].Value.Trim('"').Trim()
    if ([string]::IsNullOrWhiteSpace($tagVal) -or $tagVal -eq '{}' -or $tagVal -eq '') {
        $noTagCount++
    } else {
        # Count distinct tag strings
        if (-not $tagSamples.ContainsKey($tagVal)) { $tagSamples[$tagVal] = 0 }
        $tagSamples[$tagVal]++
        # Parse keys from JSON-like  {"key":"val","key2":"val2"}
        $keys = [regex]::Matches($tagVal, '"([^"]+)"\s*:')
        foreach ($k in $keys) {
            $key = $k.Groups[1].Value.ToLower()
            if (-not $tagKeyFreq.ContainsKey($key)) { $tagKeyFreq[$key] = 0 }
            $tagKeyFreq[$key]++
        }
    }
}
$reader.Close(); $gz.Close()

$tagged = $rowCount - $noTagCount
Write-Host "=== TAG COVERAGE ==="
Write-Host "Rows sampled    : $rowCount"
Write-Host "No / empty tags : $noTagCount  ($([math]::Round($noTagCount*100/$rowCount,1))%)"
Write-Host "Tagged rows     : $tagged  ($([math]::Round($tagged*100/$rowCount,1))%)"
Write-Host "Distinct tag strings: $($tagSamples.Count)"
Write-Host ""
Write-Host "=== TAG KEY FREQUENCY (all tagged rows) ==="
$tagKeyFreq.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    Write-Host "  $([math]::Round($_.Value*100/$tagged,1))%  [$($_.Value)x]  $($_.Key)"
}
Write-Host ""
Write-Host "=== TOP 40 DISTINCT TAG SETS (by row frequency) ==="
$tagSamples.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 40 | ForEach-Object {
    Write-Host "[$($_.Value)x] $($_.Key.Substring(0,[Math]::Min(250, $_.Key.Length)))"
}
