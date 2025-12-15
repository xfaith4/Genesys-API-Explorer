### BEGIN FILE: tests\GenesysCloud.OpsInsights.Tests.ps1
# Pester scaffold (v5)
Describe 'GenesysCloud.OpsInsights' {
    It 'Loads the module' {
        $here = Split-Path -Parent $PSCommandPath
        $repo = Split-Path -Parent $here
        $module = Join-Path $repo 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
        { Import-Module $module -Force -ErrorAction Stop } | Should -Not -Throw
    }
}
### END FILE: tests\GenesysCloud.OpsInsights.Tests.ps1
