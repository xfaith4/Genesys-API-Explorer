### BEGIN FILE: Private\Resolve-GCAuth.ps1
function Resolve-GCAuth {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BaseUri,

        [Parameter()]
        [string]$AccessToken
    )

    $ctx = Get-GCContext

    $resolvedBaseUri = $BaseUri
    if ([string]::IsNullOrWhiteSpace($resolvedBaseUri)) {
        if (-not $ctx.Connected -or [string]::IsNullOrWhiteSpace($ctx.BaseUri)) {
            throw "Not connected. Call Connect-GCCloud (or pass -BaseUri explicitly)."
        }
        $resolvedBaseUri = $ctx.BaseUri
    }

    $resolvedToken = $AccessToken
    if ([string]::IsNullOrWhiteSpace($resolvedToken)) {
        if (-not $ctx.Connected -or [string]::IsNullOrWhiteSpace($ctx.AccessToken)) {
            throw "No access token available. Call Connect-GCCloud (or pass -AccessToken explicitly)."
        }
        $resolvedToken = $ctx.AccessToken
    }

    [pscustomobject]@{
        BaseUri     = $resolvedBaseUri
        AccessToken = $resolvedToken
        Connected   = $ctx.Connected
        TokenProvider = $ctx.TokenProvider
        TraceEnabled  = $ctx.TraceEnabled
    }
}
### END FILE: Private\Resolve-GCAuth.ps1
