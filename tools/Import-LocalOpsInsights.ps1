### BEGIN FILE: tools\Import-LocalOpsInsights.ps1
# Import the module from the repo without requiring PSModulePath changes
$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $repoRoot 'src\GenesysCloud.OpsInsights'

# If your module is already built/manifested differently, adjust this path once and keep it stable.
$psm1 = Join-Path $moduleRoot 'GenesysCloud.OpsInsights.psm1'
if (-not (Test-Path -LiteralPath $psm1)) {
    throw "Module entrypoint not found: $($psm1)"
}

Import-Module -Name $psm1 -Force
### END FILE
