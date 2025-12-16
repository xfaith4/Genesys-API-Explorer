### BEGIN FILE: tools\Build.ps1
[CmdletBinding()]
param()

# Minimal build placeholder:
# - In the real pipeline this will:
#   - run Pester
#   - run PSScriptAnalyzer
#   - generate a versioned release zip
#   - (optional) sign the module
$repoRoot = Split-Path -Parent $PSCommandPath | Split-Path -Parent
$moduleRoot = Join-Path $repoRoot 'src\GenesysCloud.OpsInsights'

Write-Host "Module root: $moduleRoot"
Write-Host "TODO: Add Pester + PSScriptAnalyzer + packaging."
### END FILE: tools\Build.ps1
