# Thin façade module:
# - Keeps legacy import path stable
# - Imports Core engine from a relative path (repo-local)
# - Re-exports Core public functions

$corePsd1 = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($PSScriptRoot, '..', 'GenesysCloud.OpsInsights.Core', 'GenesysCloud.OpsInsights.Core.psd1')
)

if (-not (Test-Path -LiteralPath $corePsd1)) {
    throw "Core module not found at expected path: $($corePsd1)"
}

Import-Module -Name $corePsd1 -Force -ErrorAction Stop

$coreFuncs = Get-Command -Module GenesysCloud.OpsInsights.Core -CommandType Function | Select-Object -ExpandProperty Name
Export-ModuleMember -Function $coreFuncs
