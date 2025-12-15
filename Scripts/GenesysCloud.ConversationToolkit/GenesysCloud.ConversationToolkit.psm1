### BEGIN FILE: Scripts\GenesysCloud.ConversationToolkit\GenesysCloud.ConversationToolkit.psm1
# Compatibility shim:
# The canonical implementation moved to GenesysCloud.OpsInsights.
# This module remains so existing scripts/imports don't break.

Set-StrictMode -Version Latest

$imported = $false

# 1) Prefer a normal module install name
try {
    Import-Module -Name 'GenesysCloud.OpsInsights' -ErrorAction Stop
    $imported = $true
}
catch {
    $imported = $false
}

# 2) Dev repo-relative import (works when running from this repo)
if (-not $imported) {
    try {
        $repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
        $manifest = Join-Path $repoRoot 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
        if (Test-Path $manifest) {
            Import-Module $manifest -Force -ErrorAction Stop
            $imported = $true
        }
    }
    catch {
        $imported = $false
    }
}

if (-not $imported) {
    throw "GenesysCloud.OpsInsights module not found. Install/import it first, or run from the repo root with src\GenesysCloud.OpsInsights present."
}

# Re-export the toolkit functions for backwards compatibility
Export-ModuleMember -Function @(
    'Invoke-GCRequest',
    'Get-GCConversationTimeline',
    'Export-GCConversationToExcel',
    'Get-GCQueueSmokeReport',
    'Get-GCQueueHotConversations',
    'Show-GCConversationTimelineUI',
    'Invoke-GCSmokeDrill'
)
### END FILE: Scripts\GenesysCloud.ConversationToolkit\GenesysCloud.ConversationToolkit.psm1
