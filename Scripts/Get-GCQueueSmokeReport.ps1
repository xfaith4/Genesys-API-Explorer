### BEGIN FILE: Scripts\Get-GCQueueSmokeReport.ps1
<#
.SYNOPSIS
Back-compat wrapper. Canonical implementation lives in GenesysCloud.OpsInsights.
#>

# Import local Core module (dev-friendly)
. (Join-Path $PSScriptRoot '..\tools\Import-LocalOpsInsights.ps1')

function Get-GCQueueSmokeReport {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUri,

    [Parameter(Mandatory = $true)]
    [string]$AccessToken,

    [Parameter(Mandatory = $true)]
    [string]$Interval,

    [Parameter(Mandatory = $false)]
    [string]$DivisionId,

    [Parameter(Mandatory = $false)]
    [string[]]$QueueIds,

    [Parameter(Mandatory = $false)]
    [int]$TopN = 10
)

    Write-Verbose "NOTE: Get-GCQueueSmokeReport script wrapper is deprecated. Import GenesysCloud.OpsInsights and call the module function directly."

    # Forward to the canonical module implementation
    return GenesysCloud.OpsInsights\Get-GCQueueSmokeReport @PSBoundParameters
}
### END FILE: Scripts\Get-GCQueueSmokeReport.ps1
