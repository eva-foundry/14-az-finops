$cluster = "https://marcofinopsadx.canadacentral.kusto.windows.net"
$db      = "finopsdb"

Write-Host "Getting token..."
$t = (az account get-access-token --resource $cluster -o json | ConvertFrom-Json).accessToken
Write-Host "Token acquired: $($t.Substring(0,20))..."

$csl = Get-Content "$PSScriptRoot\kql\08-normalized-costs-function.kql" -Raw
Write-Host "KQL length: $($csl.Length) chars"

$body = @{ db = $db; csl = $csl } | ConvertTo-Json -Compress -Depth 5
Write-Host "Body length: $($body.Length)"

$resp = Invoke-WebRequest -Method POST -Uri "$cluster/v1/rest/mgmt" `
    -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
    -Body $body -SkipHttpErrorCheck
Write-Host "HTTP $($resp.StatusCode)"
Write-Host $resp.Content
