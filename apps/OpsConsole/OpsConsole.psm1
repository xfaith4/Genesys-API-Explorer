$moduleRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$coreManifest = Join-Path -Path $repoRoot -ChildPath "src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1"
if (-not (Test-Path -LiteralPath $coreManifest)) {
    throw "OpsInsights core module not found at $coreManifest"
}

Import-Module -Name $coreManifest -Force -ErrorAction Stop

$resourceScript = Join-Path -Path $moduleRoot -ChildPath "Resources/GenesysCloudAPIExplorer.ps1"
if (-not (Test-Path -LiteralPath $resourceScript)) {
    throw "OpsConsole UI script not found at $resourceScript"
}

function Start-GCOpsConsole {
    [CmdletBinding()]
    param()

    # Ensure the core transport toolbox is available before starting the UI
    Import-Module -Name $coreManifest -Force -ErrorAction Stop

    . $resourceScript
}

Export-ModuleMember -Function 'Start-GCOpsConsole'
