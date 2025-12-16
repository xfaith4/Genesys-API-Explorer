### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Invoke-GCInsightPack.ps1
function Invoke-GCInsightPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackPath,

        [Parameter()]
        [hashtable]$Parameters
    )

    if (-not (Test-Path -LiteralPath $PackPath)) {
        throw "Insight pack not found: $PackPath"
    }

    # PS 5.1-safe null handling (no ?? operator)
    if ($null -eq $Parameters) { $Parameters = @{} }

    $packJson = Get-Content -LiteralPath $PackPath -Raw
    $pack = $packJson | ConvertFrom-Json

    # For PR2, we keep this intentionally simple: return the parsed pack + parameters.
    # PR4+ will execute steps/queries, apply thresholds, generate drilldowns, etc.
    [pscustomobject]@{
        Pack         = $pack
        Parameters   = $Parameters
        Data         = @{}
        Metrics      = @()
        GeneratedUtc = (Get-Date).ToUniversalTime()
    }
}
### END FILE: src\GenesysCloud.OpsInsights\Public\Invoke-GCInsightPack.ps1
