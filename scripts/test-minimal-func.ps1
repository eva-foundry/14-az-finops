$cluster = "https://marcofinopsadx.canadacentral.kusto.windows.net"
$db      = "finopsdb"
$t = (az account get-access-token --resource $cluster -o json | ConvertFrom-Json).accessToken
Write-Host "Token OK: $($t.Length) chars"

# Test minimal function
$csl = '.create-or-alter function TestPing() { print x="OK" }'
$body = @{ db = $db; csl = $csl } | ConvertTo-Json -Compress
$resp = Invoke-WebRequest -Method POST -Uri "$cluster/v1/rest/mgmt" `
    -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
    -Body $body -SkipHttpErrorCheck
Write-Host "MINIMAL FUNC -> HTTP $($resp.StatusCode)"
if ($resp.StatusCode -ge 400) { Write-Host $resp.Content }
else {
    Write-Host "Minimal OK! Testing full KQL..."
    $csl2 = Get-Content "$PSScriptRoot\kql\08-normalized-costs-function.kql" -Raw
    # strip comments (lines starting with //) to isolate syntax
    $body2 = @{ db = $db; csl = $csl2 } | ConvertTo-Json -Compress
    $resp2 = Invoke-WebRequest -Method POST -Uri "$cluster/v1/rest/mgmt" `
        -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
        -Body $body2 -SkipHttpErrorCheck
    Write-Host "FULL FUNC -> HTTP $($resp2.StatusCode)"
    Write-Host $resp2.Content
}
