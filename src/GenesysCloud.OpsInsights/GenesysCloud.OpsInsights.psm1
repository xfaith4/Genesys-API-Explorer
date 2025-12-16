### BEGIN FILE: GenesysCloud.OpsInsights.psm1
Set-StrictMode -Version Latest

# Region: module state
$script:GCContext = [ordered]@{
    Connected     = $false
    BaseUri       = $null
    Region        = $null
    AccessToken   = $null     # In-memory token only (do not persist raw tokens)
    TokenProvider = $null     # Optional ScriptBlock to refresh token
    TracePath     = $null
    TraceEnabled  = $false
}

# Region: load Public/Private functions
$moduleRoot = Split-Path -Parent $PSCommandPath

Get-ChildItem -Path (Join-Path $moduleRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

Get-ChildItem -Path (Join-Path $moduleRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

### END FILE: GenesysCloud.OpsInsights.psm1
