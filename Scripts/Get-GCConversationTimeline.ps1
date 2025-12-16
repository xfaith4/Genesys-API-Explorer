### BEGIN FILE: Scripts\Get-GCConversationTimeline.ps1
<#
.SYNOPSIS
Back-compat wrapper. Canonical implementation lives in GenesysCloud.OpsInsights.
#>

# Import local Core module (dev-friendly)
. (Join-Path $PSScriptRoot '..\tools\Import-LocalOpsInsights.ps1')

function Get-GCConversationTimeline {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUri,

    [Parameter(Mandatory = $true)]
    [string]$AccessToken,

    [Parameter(Mandatory = $true)]
    [string]$ConversationId
)

    Write-Verbose "NOTE: Get-GCConversationTimeline script wrapper is deprecated. Import GenesysCloud.OpsInsights and call the module function directly."

    # Forward to the canonical module implementation
    return GenesysCloud.OpsInsights\Get-GCConversationTimeline @PSBoundParameters
}
### END FILE: Scripts\Get-GCConversationTimeline.ps1
