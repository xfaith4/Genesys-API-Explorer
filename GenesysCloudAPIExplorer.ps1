$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath 'apps/OpsConsole'
$manifestPath = Join-Path -Path $moduleRoot -ChildPath 'OpsConsole.psd1'
if (-not (Test-Path -Path $manifestPath)) {
    throw "OpsConsole module manifest not found: $manifestPath"
}

Import-Module -Name $manifestPath -Force -ErrorAction Stop
Start-GCOpsConsole
