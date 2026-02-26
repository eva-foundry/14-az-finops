$cluster = "https://marcofinopsadx.canadacentral.kusto.windows.net"
$db = "finopsdb"
$t = (az account get-access-token --resource $cluster -o json | ConvertFrom-Json).accessToken
$q = "NormalizedCosts() | summarize Rows = count() by CanonicalEnvironment | order by Rows desc"
$body = @{ db = $db; csl = $q } | ConvertTo-Json -Compress
$r = Invoke-RestMethod -Method POST -Uri "$cluster/v1/rest/query" `
    -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } -Body $body
$cols = $r.Tables[0].Columns | ForEach-Object { $_.ColumnName }
$r.Tables[0].Rows | ForEach-Object {
    $row=$_; $out=[ordered]@{}
    for($i=0;$i -lt $cols.Count;$i++){$out[$cols[$i]]=$row[$i]}
    Write-Host ($out | ConvertTo-Json -Compress)
}
