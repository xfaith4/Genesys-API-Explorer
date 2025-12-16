### BEGIN FILE: Public\Get-GCContext.ps1
function Get-GCContext {
    [CmdletBinding()]
    param()

    # Return a copy so callers can’t mutate module state accidentally
    [pscustomobject]@{
        Connected    = [bool]$script:GCContext.Connected
        BaseUri      = [string]$script:GCContext.BaseUri
        Region       = [string]$script:GCContext.Region
        TraceEnabled = [bool]$script:GCContext.TraceEnabled
        TracePath    = [string]$script:GCContext.TracePath
    }
}
### END FILE: Public\Get-GCContext.ps1
