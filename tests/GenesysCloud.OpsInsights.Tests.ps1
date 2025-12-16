### BEGIN FILE: tests\GenesysCloud.OpsInsights.Tests.ps1
Describe 'GenesysCloud.OpsInsights' {

    BeforeAll {
        $here = Split-Path -Parent $PSCommandPath
        $repo = Split-Path -Parent $here
        $module = Join-Path $repo 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
        Import-Module $module -Force -ErrorAction Stop
    }

    It 'Loads the module' {
        $true | Should -BeTrue
    }

    It 'Core module owns consolidated functions' {
        $names = @(
            'Get-GCConversationTimeline',
            'Get-GCQueueSmokeReport',
            'Invoke-GCSmokeDrill',
            'Get-GCConversationDetails'
        )

        foreach ($n in $names) {
            (Get-Command $n -ErrorAction Stop).Source | Should -Be 'GenesysCloud.OpsInsights'
        }
    }
}
### END FILE
