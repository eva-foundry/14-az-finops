# exec-kql.ps1 — Execute a KQL command file against ADX
param(
    [string]$KqlFile,
    [string]$Cluster  = "https://marcofinopsadx.canadacentral.kusto.windows.net",
    [string]$Database = "finopsdb"
)
$t    = (az account get-access-token --resource $Cluster -o json | ConvertFrom-Json).accessToken
$csl  = Get-Content $KqlFile -Raw
$body = @{ db = $Database; csl = $csl } | ConvertTo-Json -Compress
$r    = Invoke-RestMethod -Method POST -Uri "$Cluster/v1/rest/mgmt" `
    -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
    -Body $body
Write-Host "[OK] $KqlFile" -ForegroundColor Green
$r.Tables[0].Rows | ForEach-Object { Write-Host "  $_" }
