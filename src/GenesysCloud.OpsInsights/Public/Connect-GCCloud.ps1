### BEGIN FILE: Public\Connect-GCCloud.ps1
function Connect-GCCloud {
    [CmdletBinding()]
    param(
        # e.g. 'mypurecloud.com', 'use2.us-gov-pure.cloud', etc.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RegionDomain,

        # OAuth access token (bearer). Keep in memory; do NOT write to disk.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken,

        # Optional: ScriptBlock that returns a fresh access token string when invoked.
        # Useful when you implement Authorization Code + refresh token flow later.
        [Parameter()]
        [scriptblock]$TokenProvider
    )

    # Normalize the base API URI
    $baseUri = "https://api.$($RegionDomain)"

    $script:GCContext.BaseUri       = $baseUri
    $script:GCContext.Region        = $RegionDomain
    $script:GCContext.AccessToken   = $AccessToken
    $script:GCContext.TokenProvider = $TokenProvider
    $script:GCContext.Connected     = $true

    Write-Verbose ("Connected to {0}" -f $($script:GCContext.BaseUri))
    Get-GCContext
}
### END FILE: Public\Connect-GCCloud.ps1
