### BEGIN FILE: Scripts\GenesysCloud.ConversationToolkit\GenesysCloud.ConversationToolkit.psm1
# Compatibility shim: keep existing imports working, but actual implementation lives in GenesysCloud.OpsInsights.

$ErrorActionPreference = 'Stop'

function Import-OpsInsights {
    # Prefer repo-relative import when running from source
    $repoPsd1 = Join-Path $PSScriptRoot '..\..\src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
    if (Test-Path -LiteralPath $repoPsd1) {
        Import-Module -Name $repoPsd1 -Force
        return
    }

    # Otherwise fall back to module name (installed scenario)
    Import-Module -Name 'GenesysCloud.OpsInsights' -Force
}

Import-OpsInsights

# Re-export the public surface area expected by existing scripts
Export-ModuleMember -Function @(
    'Get-GCConversationTimeline',
    'Get-GCQueueSmokeReport',
    'Invoke-GCSmokeDrill',
    'Get-GCConversationDetails',
    'Export-GCConversationToExcel'
)
### END FILE
