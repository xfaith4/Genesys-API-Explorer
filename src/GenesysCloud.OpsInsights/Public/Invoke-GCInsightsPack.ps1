### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Invoke-GCInsightsPack.ps1
function Invoke-GCInsightsPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackPath,

        [Parameter()]
        [hashtable]$Parameters
    )

    # Forward legacy plural name to the current single-pack entry point.
    Invoke-GCInsightPack @PSBoundParameters
}
### END FILE: src\GenesysCloud.OpsInsights\Public\Invoke-GCInsightsPack.ps1
