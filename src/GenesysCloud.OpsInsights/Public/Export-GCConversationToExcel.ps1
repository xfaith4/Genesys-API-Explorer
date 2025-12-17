### BEGIN FILE: Public\Export-GCConversationToExcel.ps1
function Export-GCConversationToExcel {
    <#
        .SYNOPSIS
        Exports Genesys Cloud conversation timeline data to a professionally formatted Excel workbook.

        .DESCRIPTION
        Takes the output from Get-GCConversationTimeline and exports it to Excel with:
          - TableStyle Light11 for elegant formatting
          - AutoFilter enabled for easy data filtering
          - AutoSize columns for optimal readability
          - Multiple worksheets for different data sources (Timeline, Core, Analytics, etc.)
          - Professional presentation suitable for executive reporting

        This function requires the ImportExcel PowerShell module.
        Install it with: Install-Module ImportExcel -Scope CurrentUser

        .PARAMETER ConversationData
        The conversation data object returned by Get-GCConversationTimeline.
        Must contain TimelineEvents property at minimum.

        .PARAMETER OutputPath
        Full path where the Excel file should be saved.
        If not provided, defaults to ConversationTimeline_{ConversationId}_{timestamp}.xlsx
        in the current directory.

        .PARAMETER IncludeRawData
        Switch to include additional worksheets with raw Core, Analytics, and other data sources.
        By default, only the timeline events are exported.

        .EXAMPLE
        $timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId
        Export-GCConversationToExcel -ConversationData $timeline -OutputPath "C:\Reports\Conversation.xlsx"

        .EXAMPLE
        $timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId
        Export-GCConversationToExcel -ConversationData $timeline -IncludeRawData
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$ConversationData,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeRawData
    )


    # Check if ImportExcel module is available
    $hasImportExcel = $false
    try {
        $hasImportExcel = [bool](Get-Module -ListAvailable -Name ImportExcel)
    }
    catch { 
        $hasImportExcel = $false 
    }

    if (-not $hasImportExcel) {
        Write-Warning "ImportExcel module not found. Falling back to CSV exports."
        
        # --- CSV fallback (portable, zero-deps) ---
        $outDir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($OutputPath))
        if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath)

        # Timeline
        $timeline = $ConversationData.TimelineEvents
        $timelineCsv = Join-Path $outDir ($baseName + '_Timeline.csv')
        $timeline | Export-Csv -Path $timelineCsv -NoTypeInformation -Encoding UTF8

        # Core + Analytics (raw payloads flattened to JSON where needed)
        if ($ConversationData.Raw) {
            $coreJson = Join-Path $outDir ($baseName + '_Core.json')
            ($ConversationData.Raw.CoreConversation | ConvertTo-Json -Depth 30) | Set-Content -Path $coreJson -Encoding UTF8

            $analyticsJson = Join-Path $outDir ($baseName + '_AnalyticsDetails.json')
            ($ConversationData.Raw.AnalyticsDetails | ConvertTo-Json -Depth 30) | Set-Content -Path $analyticsJson -Encoding UTF8
        }

        Write-Host ("CSV/JSON fallback export created under: {0}" -f $outDir)
        return
    }

    # Check if ImportExcel module is available (should be true here)
    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
        Write-Error "ImportExcel module is required but not installed. Please run: Install-Module ImportExcel -Scope CurrentUser"
        return
    }

    # Import the module if not already loaded
    if (-not (Get-Module -Name ImportExcel)) {
        Import-Module ImportExcel -ErrorAction Stop
    }

    # Generate default output path if not provided
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $convId = $ConversationData.ConversationId
        $OutputPath = Join-Path -Path $PWD -ChildPath "ConversationTimeline_${convId}_${timestamp}.xlsx"
    }

    Write-Verbose "Exporting conversation data to: $OutputPath"

    # Ensure output directory exists
    $outputDir = Split-Path -Path $OutputPath -Parent
    if (-not (Test-Path -Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    # Remove existing file if present
    if (Test-Path -Path $OutputPath) {
        Remove-Item -Path $OutputPath -Force
        Write-Verbose "Removed existing file: $OutputPath"
    }

    # Export Timeline Events - Main worksheet with professional formatting
    if ($ConversationData.TimelineEvents -and $ConversationData.TimelineEvents.Count -gt 0) {
        Write-Verbose "Exporting $($ConversationData.TimelineEvents.Count) timeline events..."
        
        # Flatten the Extra column for better Excel display
        $flattenedEvents = $ConversationData.TimelineEvents | ForEach-Object {
            $event = $_
            $extraProps = @{}
            
            if ($event.Extra) {
                foreach ($key in $event.Extra.Keys) {
                    $value = $event.Extra[$key]
                    # Convert arrays and objects to strings for Excel compatibility
                    if ($value -is [array]) {
                        $extraProps["Extra_$key"] = ($value -join ', ')
                    }
                    elseif ($value -is [hashtable] -or $value -is [PSCustomObject]) {
                        $extraProps["Extra_$key"] = ($value | ConvertTo-Json -Compress)
                    }
                    else {
                        $extraProps["Extra_$key"] = $value
                    }
                }
            }
            
            # Create flattened object with all properties in one step
            $allProps = [ordered]@{
                ConversationId = $event.ConversationId
                StartTime      = $event.StartTime
                EndTime        = $event.EndTime
                Source         = $event.Source
                EventType      = $event.EventType
                Participant    = $event.Participant
                Queue          = $event.Queue
                User           = $event.User
                Direction      = $event.Direction
                DisconnectType = $event.DisconnectType
            }
            
            # Add extra properties
            foreach ($key in $extraProps.Keys) {
                $allProps[$key] = $extraProps[$key]
            }
            
            [PSCustomObject]$allProps
        }

        $flattenedEvents | Export-Excel -Path $OutputPath `
            -WorksheetName "Timeline Events" `
            -TableName "ConversationTimeline" `
            -TableStyle Light11 `
            -AutoFilter `
            -AutoSize `
            -FreezeTopRow `
            -BoldTopRow
    }
    else {
        Write-Warning "No timeline events found in conversation data."
    }

    # Export additional raw data if requested
    if ($IncludeRawData) {
        # Core Conversation Data
        if ($ConversationData.Core) {
            Write-Verbose "Exporting core conversation data..."
            $coreFlattened = @()
            
            if ($ConversationData.Core.participants) {
                foreach ($participant in $ConversationData.Core.participants) {
                    foreach ($segment in $participant.segments) {
                        $coreFlattened += [PSCustomObject]@{
                            ConversationId = $ConversationData.ConversationId
                            ParticipantId  = $participant.participantId
                            ParticipantName = $participant.name
                            UserId         = $participant.userId
                            QueueId        = $participant.queueId
                            Purpose        = $participant.purpose
                            SegmentType    = $segment.segmentType
                            SegmentStart   = $segment.segmentStart
                            SegmentEnd     = $segment.segmentEnd
                            Direction      = $segment.direction
                            DisconnectType = $segment.disconnectType
                            Ani            = $segment.ani
                            Dnis           = $segment.dnis
                            WrapUpCode     = $segment.wrapUpCode
                        }
                    }
                }
            }
            
            if ($coreFlattened.Count -gt 0) {
                $coreFlattened | Export-Excel -Path $OutputPath `
                    -WorksheetName "Core Conversation" `
                    -TableName "CoreConversation" `
                    -TableStyle Light11 `
                    -AutoFilter `
                    -AutoSize `
                    -FreezeTopRow `
                    -BoldTopRow
            }
        }

        # Analytics Details
        if ($ConversationData.AnalyticsDetails -and $ConversationData.AnalyticsDetails.participants) {
            Write-Verbose "Exporting analytics details..."
            $analyticsFlattened = @()
            
            foreach ($participant in $ConversationData.AnalyticsDetails.participants) {
                foreach ($session in $participant.sessions) {
                    foreach ($segment in $session.segments) {
                        $analyticsFlattened += [PSCustomObject]@{
                            ConversationId  = $ConversationData.ConversationId
                            ParticipantId   = $participant.participantId
                            ParticipantName = $participant.participantName
                            Purpose         = $participant.purpose
                            SessionId       = $session.sessionId
                            MediaType       = $session.mediaType
                            Direction       = $session.direction
                            SegmentType     = $segment.segmentType
                            SegmentStart    = $segment.segmentStart
                            SegmentEnd      = $segment.segmentEnd
                            QueueId         = $segment.queueId
                            DisconnectType  = $segment.disconnectType
                            ErrorCode       = $segment.errorCode
                        }
                    }
                }
            }
            
            if ($analyticsFlattened.Count -gt 0) {
                $analyticsFlattened | Export-Excel -Path $OutputPath `
                    -WorksheetName "Analytics Details" `
                    -TableName "AnalyticsDetails" `
                    -TableStyle Light11 `
                    -AutoFilter `
                    -AutoSize `
                    -FreezeTopRow `
                    -BoldTopRow
            }
        }

        # Media Endpoint Stats (if available in analytics)
        if ($ConversationData.AnalyticsDetails -and $ConversationData.AnalyticsDetails.participants) {
            Write-Verbose "Extracting MediaEndpointStats..."
            $mediaStats = @()
            
            foreach ($participant in $ConversationData.AnalyticsDetails.participants) {
                foreach ($session in $participant.sessions) {
                    if ($session.metrics) {
                        foreach ($metric in $session.metrics) {
                            $mediaStats += [PSCustomObject]@{
                                ConversationId  = $ConversationData.ConversationId
                                ParticipantId   = $participant.participantId
                                SessionId       = $session.sessionId
                                MediaType       = $session.mediaType
                                MetricName      = $metric.name
                                MetricValue     = $metric.value
                                EmitDate        = $metric.emitDate
                            }
                        }
                    }
                }
            }
            
            if ($mediaStats.Count -gt 0) {
                $mediaStats | Export-Excel -Path $OutputPath `
                    -WorksheetName "Media Stats" `
                    -TableName "MediaEndpointStats" `
                    -TableStyle Light11 `
                    -AutoFilter `
                    -AutoSize `
                    -FreezeTopRow `
                    -BoldTopRow
            }
        }

        # SIP Messages
        if ($ConversationData.SipMessages -and $ConversationData.SipMessages.Count -gt 0) {
            Write-Verbose "Exporting SIP messages..."
            $sipFlattened = $ConversationData.SipMessages | ForEach-Object {
                [PSCustomObject]@{
                    ConversationId = $ConversationData.ConversationId
                    Timestamp      = $_.timestamp
                    Method         = $_.method
                    StatusCode     = $_.statusCode
                    ReasonPhrase   = $_.reasonPhrase
                    Direction      = $_.direction
                    ParticipantId  = $_.participantId
                }
            }
            
            $sipFlattened | Export-Excel -Path $OutputPath `
                -WorksheetName "SIP Messages" `
                -TableName "SIPMessages" `
                -TableStyle Light11 `
                -AutoFilter `
                -AutoSize `
                -FreezeTopRow `
                -BoldTopRow
        }

        # Sentiment Data
        if ($ConversationData.Sentiments -and $ConversationData.Sentiments.sentiment) {
            Write-Verbose "Exporting sentiment data..."
            $sentimentFlattened = $ConversationData.Sentiments.sentiment | ForEach-Object {
                [PSCustomObject]@{
                    ConversationId = $ConversationData.ConversationId
                    Time           = $_.time
                    ParticipantId  = $_.participantId
                    UserId         = $_.userId
                    Score          = $_.score
                    Label          = $_.label
                }
            }
            
            $sentimentFlattened | Export-Excel -Path $OutputPath `
                -WorksheetName "Sentiment Analysis" `
                -TableName "SentimentData" `
                -TableStyle Light11 `
                -AutoFilter `
                -AutoSize `
                -FreezeTopRow `
                -BoldTopRow
        }
    }

    Write-Host "✓ Conversation data exported successfully to: $OutputPath" -ForegroundColor Green
    
    # Return the output path for pipeline use
    return [PSCustomObject]@{
        OutputPath     = $OutputPath
        ConversationId = $ConversationData.ConversationId
        EventCount     = if ($ConversationData.TimelineEvents) { $ConversationData.TimelineEvents.Count } else { 0 }
    }
}
### END FILE: Public\Export-GCConversationToExcel.ps1
