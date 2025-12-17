### BEGIN FILE: tests\GenesysCloud.OpsInsights.Tests.ps1
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
            ($intervalParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | 
                Should -Contain $true
        }

        It 'Get-GCRoutingStatusReport Interval parameter is mandatory' {
            $command = Get-Command Get-GCRoutingStatusReport
            $intervalParam = $command.Parameters['Interval']
            ($intervalParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | 
                Should -Contain $true
        }

        It 'Exports Get-GCPeakConcurrentVoice function' {
            $command = Get-Command Get-GCPeakConcurrentVoice -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty
            $command.CommandType | Should -Be 'Function'
        }

        It 'Get-GCPeakConcurrentVoice computes peak from fixture data' {
            $here = Split-Path -Parent $PSCommandPath
            $fixturePath = Join-Path $here 'fixtures/ConversationDetails.sample.json'
            $payload = Get-Content $fixturePath | ConvertFrom-Json

            $result = Get-GCPeakConcurrentVoice -Interval '2024-02-01T00:00:00Z/2024-03-01T00:00:00Z' -Conversations $payload.conversations

            $result.PeakConcurrentCalls | Should -Be 10
            $result.FirstPeakMinuteUtc | Should -Be ([datetime]'2024-02-16T18:23:00Z')
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

    Context 'Export-GCConversationToExcel' {
        It 'Exports timeline data to a file path' {
            $conversation = [pscustomobject]@{
                ConversationId   = 'conv-123'
                TimelineEvents   = @(
                    [pscustomobject]@{
                        ConversationId = 'conv-123'
                        StartTime      = [datetime]'2025-01-01T00:00:00Z'
                        EndTime        = [datetime]'2025-01-01T00:05:00Z'
                        Source         = 'Core'
                        EventType      = 'start'
                        Participant    = 'caller'
                        Queue          = 'queue-1'
                        User           = 'user-1'
                        Direction      = 'inbound'
                        DisconnectType = 'client'
                        Extra          = @{ Note = 'hello' }
                    }
                )
                Core             = @{ foo = 'bar' }
                AnalyticsDetails = @{ data = @{ stat = 1 } }
            }

            $outPath = Join-Path $TestDrive 'conversation.xlsx'
            $result = Export-GCConversationToExcel -ConversationData $conversation -OutputPath $outPath -IncludeRawData -Force

            $result | Should -Not -BeNullOrEmpty
            $result.Format | Should -BeIn @('Csv','Xlsx')

            if ($result.Format -eq 'Csv') {
                Test-Path $result.TimelinePath | Should -BeTrue
                (Import-Csv -LiteralPath $result.TimelinePath).Count | Should -Be 1
                $result.RawPaths.Keys | Should -Contain 'Core'
                Test-Path $result.RawPaths['Core'] | Should -BeTrue
            }
            else {
                Test-Path $result.Path | Should -BeTrue
            }
        }
    }
}
### END FILE
