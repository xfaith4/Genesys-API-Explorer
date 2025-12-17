# Set up the Genesys Cloud OpsInsights module by loading private helpers first, then public commands.

$moduleRoot = $PSScriptRoot
if (-not (Test-Path -LiteralPath $moduleRoot)) {
    throw "Module root not found: $($moduleRoot)"
}

 $coreManifest = [System.IO.Path]::Combine($moduleRoot, '..', 'GenesysCloud.OpsInsights.Core', 'GenesysCloud.OpsInsights.Core.psd1')
 if (Test-Path -LiteralPath $coreManifest) {
     Import-Module -Name $coreManifest -Force -ErrorAction Stop
 }

if (-not $script:GCContext) {
    $script:GCContext = [pscustomobject]@{
        Connected     = $false
        BaseUri       = $null
        ApiBaseUri    = $null
        RegionDomain  = $null
        Region        = $null
        AccessToken   = $null
        TokenProvider = $null
        TraceEnabled  = $false
        TracePath     = $null
        SetUtc        = (Get-Date).ToUniversalTime()
    }
}

$privateDir = Join-Path $moduleRoot 'Private'
$publicDir  = Join-Path $moduleRoot 'Public'

$script:LoadedScripts = @()

$privateScripts = Get-ChildItem -Path $privateDir -Filter '*.ps1' -File | Sort-Object Name
foreach ($script in $privateScripts) { . $script.FullName; $script:LoadedScripts += $script.Name }

$publicScripts = Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | Sort-Object Name
foreach ($script in $publicScripts) { . $script.FullName; $script:LoadedScripts += $script.Name }

$publicFunctions = @(
    'Connect-GCCloud',
    'Disconnect-GCCloud',
    'Export-GCConversationToExcel',
    'Get-GCContext',
    'Get-GCConversationDetails',
    'Get-GCConversationTimeline',
    'Get-GCDivisionReport',
    'Get-GCQueueHotConversations',
    'Get-GCQueueSmokeReport',
    'Get-GCRoutingStatusReport',
    'Get-GCPeakConcurrentVoice',
    'Import-GCSnapshot',
    'Invoke-GCInsightPack',
    'Invoke-GCInsightsPack',
    'Export-GCInsightPackSnapshot',
    'Export-GCInsightPackExcel',
    'Export-GCInsightBriefing',
    'Invoke-GCRequest',
    'Invoke-GCSmokeDrill',
    'New-GCSnapshot',
    'Save-GCSnapshot',
    'Set-GCContext',
    'Set-GCInvoker',
    'Show-GCConversationTimelineUI',
    'Start-GCTrace',
    'Stop-GCTrace'
)

Export-ModuleMember -Function $publicFunctions
