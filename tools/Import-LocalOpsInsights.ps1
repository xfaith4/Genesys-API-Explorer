### BEGIN FILE: tools\Import-LocalOpsInsights.ps1
<#
.SYNOPSIS
Developer helper to import the local GenesysCloud.OpsInsights module from this repo (no PSModulePath install needed).

.EXAMPLE
. .\tools\Import-LocalOpsInsights.ps1
Connect-GCCloud -RegionDomain 'usw2.pure.cloud' -AccessToken $token
Get-GCConversationTimeline -ConversationId '...'
#>

[CmdletBinding()]
param()

$here = $PSScriptRoot
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $here '..'))

$moduleManifest = Join-Path $repoRoot 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
if (-not (Test-Path $moduleManifest)) {
    throw ("Module manifest not found: {0}" -f $moduleManifest)
}

Import-Module $moduleManifest -Force -ErrorAction Stop
Write-Host ("Imported GenesysCloud.OpsInsights from {0}" -f $moduleManifest)
### END FILE: tools\Import-LocalOpsInsights.ps1
