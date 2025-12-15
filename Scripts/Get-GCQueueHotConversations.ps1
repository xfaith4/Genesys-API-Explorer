### BEGIN FILE: Scripts\Get-GCQueueHotConversations.ps1
<#
.SYNOPSIS
Back-compat wrapper. Canonical implementation lives in GenesysCloud.OpsInsights.
#>

# Import local Core module (dev-friendly)
. (Join-Path $PSScriptRoot '..\tools\Import-LocalOpsInsights.ps1')

function Get-GCQueueHotConversations {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUri,

    [Parameter(Mandatory = $true)]
    [string]$AccessToken,

    [Parameter(Mandatory = $true)]
    [string]$QueueId,

    [Parameter(Mandatory = $true)]
    [string]$Interval,

    [Parameter(Mandatory = $false)]
    [int]$PageSize = 200,

    [Parameter(Mandatory = $false)]
    [int]$TopN = 25
)

    Write-Verbose "NOTE: Get-GCQueueHotConversations script wrapper is deprecated. Import GenesysCloud.OpsInsights and call the module function directly."

    # Forward to the canonical module implementation
    return GenesysCloud.OpsInsights\Get-GCQueueHotConversations @PSBoundParameters
}
### END FILE: Scripts\Get-GCQueueHotConversations.ps1
