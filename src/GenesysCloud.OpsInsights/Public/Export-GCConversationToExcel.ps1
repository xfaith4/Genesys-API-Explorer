### BEGIN FILE: Public\Export-GCConversationToExcel.ps1
function Export-GCConversationToExcel {
    <#
      .SYNOPSIS
        Export conversation timeline data to XLSX or CSV/JSON fallbacks.

      .DESCRIPTION
        - Prefers ImportExcel for XLSX export (if installed)
        - Falls back to CSV + JSON automatically if ImportExcel is unavailable
        - Writes UTF-8 for all text outputs

      .PARAMETER ConversationData
        Conversation timeline object (typically from Get-GCConversationTimeline). Pipeline supported.

      .PARAMETER OutputPath
        Target file path. Defaults to a timestamped Conversation_<id>.xlsx next to the current location.

      .PARAMETER IncludeRawData
        When set, also exports raw payloads (Core, AnalyticsDetails, etc.).

      .PARAMETER Force
        Overwrite existing files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$ConversationData,

        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [switch]$IncludeRawData,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $items = New-Object System.Collections.Generic.List[object]
    }

    process {
        if ($null -ne $ConversationData) {
            $items.Add($ConversationData) | Out-Null
        }
    }

    end {
        if ($items.Count -eq 0) { return }

        $first = $items[0]
        if (-not $OutputPath) {
            $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $baseName = if ($first.PSObject.Properties.Name -contains 'ConversationId' -and $first.ConversationId) {
                "Conversation_{0}_{1}.xlsx" -f $first.ConversationId, $stamp
            }
            else {
                "Conversation_{0}.xlsx" -f $stamp
            }

            $OutputPath = Join-Path -Path (Get-Location).ProviderPath -ChildPath $baseName
        }

        $fullPath = [System.IO.Path]::GetFullPath($OutputPath)
        $dir = [System.IO.Path]::GetDirectoryName($fullPath)
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # Flatten timeline events for export
        $timelineRows = foreach ($conv in $items) {
            if ($conv.PSObject.Properties.Name -contains 'TimelineEvents') {
                foreach ($ev in @($conv.TimelineEvents)) {
                    [pscustomobject]@{
                        ConversationId = $ev.ConversationId
                        StartTime      = $ev.StartTime
                        EndTime        = $ev.EndTime
                        Source         = $ev.Source
                        EventType      = $ev.EventType
                        Participant    = $ev.Participant
                        Queue          = $ev.Queue
                        User           = $ev.User
                        Direction      = $ev.Direction
                        DisconnectType = $ev.DisconnectType
                        Extra          = if ($ev.PSObject.Properties.Name -contains 'Extra' -and $ev.Extra) {
                            $ev.Extra | ConvertTo-Json -Depth 6 -Compress
                        } else { $null }
                    }
                }
            }
        }

        $hasImportExcel = $false
        try { $hasImportExcel = [bool](Get-Module -ListAvailable -Name ImportExcel) } catch { $hasImportExcel = $false }

        if ($hasImportExcel) {
            Import-Module ImportExcel -ErrorAction Stop

            if ((Test-Path -LiteralPath $fullPath) -and -not $Force) {
                throw "Refusing to overwrite existing file: $($fullPath). Use -Force to overwrite."
            }

            $timelineRows | Export-Excel -Path $fullPath `
                -WorksheetName 'Timeline' `
                -TableName 'Timeline' `
                -AutoSize `
                -FreezeTopRow

            if ($IncludeRawData) {
                $rawSheets = @{
                    Core             = 'Core'
                    AnalyticsDetails = 'Analytics'
                    SpeechText       = 'SpeechText'
                    RecordingMeta    = 'Recording'
                    Sentiments       = 'Sentiments'
                    SipMessages      = 'SipMessages'
                }

                foreach ($entry in $rawSheets.GetEnumerator()) {
                    $value = $first.$($entry.Key)
                    if ($null -ne $value) {
                        $data = $value
                        if ($data -is [string]) {
                            $data = @([pscustomobject]@{ Value = $data })
                        }
                        elseif ($data -isnot [System.Collections.IEnumerable] -or $data -is [hashtable]) {
                            $data = @($data)
                        }

                        @($data) | Export-Excel -Path $fullPath `
                            -WorksheetName $entry.Value `
                            -AutoSize `
                            -FreezeTopRow `
                            -AppendSheet
                    }
                }
            }

            return [pscustomobject]@{
                Format         = 'Xlsx'
                Path           = $fullPath
                TimelineCount  = $timelineRows.Count
                RawDataExported= [bool]$IncludeRawData
            }
        }

        # --- CSV/JSON fallback -------------------------------------------------
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fullPath)
        $timelinePath = Join-Path $dir ("{0}_Timeline.csv" -f $baseName)
        if ((Test-Path -LiteralPath $timelinePath) -and -not $Force) {
            throw "Refusing to overwrite existing file: $($timelinePath). Use -Force to overwrite."
        }

        $timelineRows | Export-Csv -LiteralPath $timelinePath -NoTypeInformation -Encoding utf8

        $rawPaths = @{}
        if ($IncludeRawData) {
            $rawMap = @{
                Core             = 'Core'
                AnalyticsDetails = 'AnalyticsDetails'
                SpeechText       = 'SpeechText'
                RecordingMeta    = 'RecordingMeta'
                Sentiments       = 'Sentiments'
                SipMessages      = 'SipMessages'
            }

            foreach ($key in $rawMap.Keys) {
                $value = $first.$key
                if ($null -ne $value) {
                    $file = Join-Path $dir ("{0}_{1}.json" -f $baseName, $rawMap[$key])
                    if ((Test-Path -LiteralPath $file) -and -not $Force) {
                        throw "Refusing to overwrite existing file: $($file). Use -Force to overwrite."
                    }
                    ($value | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $file -Encoding utf8
                    $rawPaths[$key] = $file
                }
            }
        }

        return [pscustomobject]@{
            Format        = 'Csv'
            TimelinePath  = $timelinePath
            RawPaths      = $rawPaths
            TimelineCount = $timelineRows.Count
        }
    }
}
### END FILE: Public\Export-GCConversationToExcel.ps1
