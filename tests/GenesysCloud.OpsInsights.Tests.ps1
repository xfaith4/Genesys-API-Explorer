### BEGIN FILE: tests\GenesysCloud.OpsInsights.Tests.ps1
# Pester scaffold (v5)
Describe 'GenesysCloud.OpsInsights' {
    BeforeAll {
        $here = Split-Path -Parent $PSCommandPath
        $repo = Split-Path -Parent $here
        $module = Join-Path $repo 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
        Import-Module $module -Force -ErrorAction Stop
    }

    It 'Loads the module' {
        $here = Split-Path -Parent $PSCommandPath
        $repo = Split-Path -Parent $here
        $module = Join-Path $repo 'src\GenesysCloud.OpsInsights\GenesysCloud.OpsInsights.psd1'
        { Import-Module $module -Force -ErrorAction Stop } | Should -Not -Throw
    }

    Context 'Reporting Functions' {
        It 'Exports Get-GCDivisionReport function' {
            $command = Get-Command Get-GCDivisionReport -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }

        It 'Exports Get-GCRoutingStatusReport function' {
            $command = Get-Command Get-GCRoutingStatusReport -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }

        It 'Get-GCDivisionReport has required parameters' {
            $command = Get-Command Get-GCDivisionReport
            $command.Parameters.Keys | Should -Contain 'Interval'
            $command.Parameters.Keys | Should -Contain 'TopN'
            $command.Parameters.Keys | Should -Contain 'BaseUri'
            $command.Parameters.Keys | Should -Contain 'AccessToken'
        }

        It 'Get-GCRoutingStatusReport has required parameters' {
            $command = Get-Command Get-GCRoutingStatusReport
            $command.Parameters.Keys | Should -Contain 'Interval'
            $command.Parameters.Keys | Should -Contain 'GroupBy'
            $command.Parameters.Keys | Should -Contain 'BaseUri'
            $command.Parameters.Keys | Should -Contain 'AccessToken'
        }

        It 'Get-GCDivisionReport Interval parameter is mandatory' {
            $command = Get-Command Get-GCDivisionReport
            $intervalParam = $command.Parameters['Interval']
            $intervalParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | 
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }

        It 'Get-GCRoutingStatusReport Interval parameter is mandatory' {
            $command = Get-Command Get-GCRoutingStatusReport
            $intervalParam = $command.Parameters['Interval']
            $intervalParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | 
                ForEach-Object { $_.Mandatory } | Should -Contain $true
        }
    }

    Context 'Get-GCQueueSmokeReport' {
        It 'Exports Get-GCQueueSmokeReport function' {
            $command = Get-Command Get-GCQueueSmokeReport -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
        }

        It 'Has required Interval parameter' {
            $command = Get-Command Get-GCQueueSmokeReport
            $command.Parameters.Keys | Should -Contain 'Interval'
        }
    }
}
### END FILE: tests\GenesysCloud.OpsInsights.Tests.ps1
