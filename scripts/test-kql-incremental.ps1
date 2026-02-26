$cluster = "https://marcofinopsadx.canadacentral.kusto.windows.net"
$db      = "finopsdb"
$t = (az account get-access-token --resource $cluster -o json | ConvertFrom-Json).accessToken

function Test-KQL($label, $kql) {
    $body = @{ db = $db; csl = $kql } | ConvertTo-Json -Compress
    $resp = Invoke-WebRequest -Method POST -Uri "$cluster/v1/rest/mgmt" `
        -Headers @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" } `
        -Body $body -SkipHttpErrorCheck
    if ($resp.StatusCode -eq 200) {
        Write-Host "[OK]  $label" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[FAIL] $label -> $($resp.Content)" -ForegroundColor Red
        return $false
    }
}

# Test 1: minimal raw_costs reference
Test-KQL "T1-raw_costs" '.create-or-alter function NC_T1() { raw_costs | take 1 }'

# Test 2: extend tags
Test-KQL "T2-tags-wrap" '.create-or-alter function NC_T2() {
    raw_costs
    | extend _TagsStr = tostring(Tags)
    | extend _TagsFixed = iif(isnotempty(_TagsStr) and (_TagsStr !startswith "{") and (_TagsStr !startswith "["), strcat("{", _TagsStr, "}"), _TagsStr)
    | extend _T = parse_json(_TagsFixed)
    | take 1
}'

# Test 3: add coalesce extracts
Test-KQL "T3-coalesce-extract" '.create-or-alter function NC_T3() {
    raw_costs
    | extend _TagsStr = tostring(Tags)
    | extend _TagsFixed = iif(isnotempty(_TagsStr) and (_TagsStr !startswith "{") and (_TagsStr !startswith "["), strcat("{", _TagsStr, "}"), _TagsStr)
    | extend _T = parse_json(_TagsFixed)
    | extend _EnvRaw = coalesce(tostring(_T.environment), tostring(_T.Environment), "")
    | take 1
}'

# Test 4: in~ case statement
Test-KQL "T4-case-in" '.create-or-alter function NC_T4() {
    raw_costs
    | extend _TagsStr = tostring(Tags)
    | extend _TagsFixed = iif(isnotempty(_TagsStr) and (_TagsStr !startswith "{") and (_TagsStr !startswith "["), strcat("{", _TagsStr, "}"), _TagsStr)
    | extend _T = parse_json(_TagsFixed)
    | extend _EnvRaw = coalesce(tostring(_T.environment), tostring(_T.Environment), "")
    | extend CanonEnv = case(
        _EnvRaw in~ ("development", "dev", "dev1", "dev2", "dev3", "dev4", "dev5"), "Dev",
        _EnvRaw in~ ("stg1", "stg2", "stage", "staging"), "Stage",
        _EnvRaw in~ ("prod", "production", "prd", "prd1"), "Prod",
        isnotempty(_EnvRaw), _EnvRaw,
        SubscriptionName
      )
    | take 1
}'

# Test 5: boolean extend
Test-KQL "T5-bool-extend" '.create-or-alter function NC_T5() {
    raw_costs
    | extend _Shared = "TRUE"
    | extend IsShared = (_Shared =~ "TRUE")
    | take 1
}'

# Test 6: full version without comment header
$fullNoComments = @'
.create-or-alter function with (folder="FinOps", docstring="NormalizedCosts v2") NormalizedCosts() {
    raw_costs
    | extend _TagsStr = tostring(Tags)
    | extend _TagsFixed = iif(isnotempty(_TagsStr) and (_TagsStr !startswith "{") and (_TagsStr !startswith "["), strcat("{", _TagsStr, "}"), _TagsStr)
    | extend _T = parse_json(_TagsFixed)
    | extend
        _EnvRaw   = coalesce(tostring(_T.environment),              tostring(_T.Environment),              ""),
        _TeamRaw  = coalesce(tostring(_T.team),                     tostring(_T.Team),                     ""),
        _Project  = coalesce(tostring(_T.fin_projectname),          tostring(_T.ProjectName),              ""),
        _FinAuth  = coalesce(tostring(_T.fin_financialauthority),   tostring(_T.Fin_FinancialAuthority),   ""),
        _MgrRaw   = coalesce(tostring(_T.manager),                  tostring(_T.Manager),                  ""),
        _Client   = tostring(_T.client),
        _SscCbrid = tostring(_T.ssc_cbrid),
        _AppId    = coalesce(tostring(_T.fin_csdid),                tostring(_T.app_id),                   ""),
        _Shared   = coalesce(tostring(_T.shared_cost),              "FALSE"),
        _SecClass = coalesce(tostring(_T.sec_classification),       tostring(_T.Classification),           ""),
        _OpsProj  = coalesce(tostring(_T.ops_projectacronym),       tostring(_T.Ops_ProjectAcronym),       "")
    | extend CanonicalEnvironment = case(
        _EnvRaw in~ ("development", "dev", "dev1", "dev2", "dev3", "dev4", "dev5"), "Dev",
        _EnvRaw in~ ("stg1", "stg2", "stage", "staging"),                           "Stage",
        _EnvRaw in~ ("prod", "production", "prd", "prd1"),                          "Prod",
        isnotempty(_EnvRaw), _EnvRaw,
        SubscriptionName
      )
    | extend EffectiveCostCenter = case(
        isnotempty(CostCenter),  CostCenter,
        isnotempty(_SscCbrid),   strcat("SSC-", _SscCbrid),
        isnotempty(_OpsProj),    _OpsProj,
        "AiCoE"
      )
    | extend EffectiveCallerApp = case(
        isnotempty(_AppId),   _AppId,
        isnotempty(_Project), _Project,
        "Pre-APIM"
      )
    | extend
        SscBillingCode     = _SscCbrid,
        FinancialAuthority = _FinAuth,
        OwnerManager       = _MgrRaw,
        ClientBu           = iif(isnotempty(_Client), _Client, _TeamRaw),
        ProjectDisplayName = _Project,
        IsSharedCost       = (_Shared =~ "TRUE"),
        SecurityClass      = _SecClass
    | project-away _TagsStr, _TagsFixed, _T, _EnvRaw, _TeamRaw, _Project,
                   _FinAuth, _MgrRaw, _Client, _SscCbrid, _AppId, _Shared,
                   _SecClass, _OpsProj, Tags
}
'@
Test-KQL "T6-full-no-comments" $fullNoComments

Write-Host "Done."
