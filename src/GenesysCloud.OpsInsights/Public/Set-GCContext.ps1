### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Set-GCContext.ps1
function Set-GCContext {
    <#
      .SYNOPSIS
        Sets module-scoped Genesys Cloud context (optional).
      .DESCRIPTION
        You do NOT need this if your GUI already sets $global:AccessToken.
        It's here for scripts that want an explicit context.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RegionDomain = 'usw2.pure.cloud',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApiBaseUri,

        [Parameter()]
        [string]$AccessToken,

        [Parameter()]
        [scriptblock]$TokenProvider
    )

    if (-not $ApiBaseUri) {
        $ApiBaseUri = "https://api.$($RegionDomain)"
    }

    $script:GCContext = [pscustomobject]@{
        RegionDomain  = $RegionDomain
        ApiBaseUri    = $ApiBaseUri
        AccessToken   = $AccessToken
        TokenProvider = $TokenProvider
        SetUtc        = (Get-Date).ToUniversalTime()
    }

    return $script:GCContext
}
### END FILE
