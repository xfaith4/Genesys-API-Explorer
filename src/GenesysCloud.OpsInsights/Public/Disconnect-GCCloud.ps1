### BEGIN FILE: Public\Disconnect-GCCloud.ps1
function Disconnect-GCCloud {
    [CmdletBinding()]
    param()

    $script:GCContext.Connected     = $false
    $script:GCContext.AccessToken   = $null
    $script:GCContext.TokenProvider = $null

    Write-Verbose "Disconnected."
}
### END FILE: Public\Disconnect-GCCloud.ps1
