### BEGIN: Get-GCConversationTimeline
function Get-GCConversationTimeline {
    <#
        .SYNOPSIS
        Pulls multiple Genesys Cloud APIs for a single conversation and returns
        both the raw payloads and a normalized, time-ordered event list.

        .DESCRIPTION
        Calls:
          - GET  /api/v2/conversations/{conversationId}
          - GET  /api/v2/analytics/conversations/{conversationId}/details
          - GET  /api/v2/speechandtextanalytics/conversations/{conversationId}
          - GET  /api/v2/conversations/{conversationId}/recordingmetadata
          - GET  /api/v2/speechandtextanalytics/conversations/{conversationId}/sentiments
          - GET  /api/v2/telephony/sipmessages/conversations/{conversationId}

        Then normalizes them into TimelineEvents you can sort / export / visualize.

        .PARAMETER BaseUri
        Base API URI for your region, e.g. https://api.usw2.pure.cloud

        .PARAMETER AccessToken
        OAuth Bearer token.

        .PARAMETER ConversationId
        ConversationId to investigate.

        .OUTPUTS
        PSCustomObject:
        {
          ConversationId,
          Core,
          AnalyticsDetails,
          SpeechText,
          RecordingMeta,
          Sentiments,
          SipMessages,
          TimelineEvents[]
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUri,

        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$ConversationId
    )

    # Local helper so this function is self-contained.
    function Invoke-GCRequest {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'PATCH')]
            [string]$Method,

            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $false)]
            [object]$Body
        )

        # Build full URI (no query support here – keep this function simple)
        $uri = $BaseUri.TrimEnd('/') + $Path

        $headers = @{
            Authorization = "Bearer $AccessToken"
        }

        $invokeParams = @{
            Method      = $Method
            Uri         = $uri
            Headers     = $headers
            ErrorAction = 'Stop'
        }

        if ($Body) {
            # If body is not a string, assume it is an object and JSON-encode it
            if ($Body -isnot [string]) {
                $invokeParams['Body'] = ($Body | ConvertTo-Json -Depth 10)
                $invokeParams['ContentType'] = 'application/json'
            }
            else {
                $invokeParams['Body'] = $Body
                $invokeParams['ContentType'] = 'application/json'
            }
        }

        return Invoke-RestMethod @invokeParams
    }

    # ---------------------------------------------
    # 1) Fetch raw payloads from Genesys Cloud
    # ---------------------------------------------
    Write-Verbose "[$ConversationId] Fetching core conversation..."
    $coreConversation = Invoke-GCRequest -Method 'GET' -Path "/api/v2/conversations/$ConversationId"

    Write-Verbose "[$ConversationId] Fetching analytics details..."
    $analyticsDetails = Invoke-GCRequest -Method 'GET' -Path "/api/v2/analytics/conversations/$ConversationId/details"

    Write-Verbose "[$ConversationId] Fetching Speech & Text Analytics..."
    $speechText = Invoke-GCRequest -Method 'GET' -Path "/api/v2/speechandtextanalytics/conversations/$ConversationId"

    Write-Verbose "[$ConversationId] Fetching recording metadata..."
    $recordingMeta = Invoke-GCRequest -Method 'GET' -Path "/api/v2/conversations/$ConversationId/recordingmetadata"

    Write-Verbose "[$ConversationId] Fetching sentiment data..."
    $sentiments = Invoke-GCRequest -Method 'GET' -Path "/api/v2/speechandtextanalytics/conversations/$ConversationId/sentiments"

    Write-Verbose "[$ConversationId] Fetching SIP messages..."
    $sipMessages = Invoke-GCRequest -Method 'GET' -Path "/api/v2/telephony/sipmessages/conversations/$ConversationId"

    # ---------------------------------------------
    # 2) Timeline normalization
    # ---------------------------------------------

    # Events list to accumulate timeline rows
    $events = [System.Collections.Generic.List[object]]::new()

    function New-TimelineEvent {
        param(
            [string]  $ConversationId,
            [string]  $Source,
            [string]  $EventType,
            [datetime]$StartTime,
            [datetime]$EndTime,
            [string]  $QueueId,
            [string]  $UserId,
            [string]  $ParticipantId,
            [hashtable]$ExtraData
        )

        $obj = [ordered]@{
            ConversationId  = $ConversationId
            Source          = $Source
            EventType       = $EventType
            StartTime       = $StartTime
            EndTime         = $EndTime
            DurationSeconds = $null
            QueueId         = $QueueId
            UserId          = $UserId
            ParticipantId   = $ParticipantId
        }

        if ($StartTime -and $EndTime -and $EndTime -gt $StartTime) {
            $obj['DurationSeconds'] = [int]([TimeSpan]::op_Subtraction($EndTime, $StartTime).TotalSeconds)
        }

        if ($ExtraData) {
            foreach ($k in $ExtraData.Keys) {
                $obj[$k] = $ExtraData[$k]
            }
        }

        return [pscustomobject]$obj
    }

    # 2a) Conversation lifecycle (start/end)
    try {
        # NOTE: property names may differ in your tenant – adjust once you inspect.
        $convStart = $coreConversation.conversationStart
        $convEnd = $coreConversation.conversationEnd

        if ($convStart) {
            $events.Add(
                (New-TimelineEvent `
                    -ConversationId $ConversationId `
                    -Source 'Conversations' `
                    -EventType 'ConversationLifecycle' `
                    -StartTime ([datetime]$convStart) `
                    -EndTime ([datetime]$convEnd) `
                    -QueueId $null `
                    -UserId $null `
                    -ParticipantId $null `
                    -ExtraData @{})
            )
        }
    }
    catch {
        Write-Warning "[$ConversationId] Failed to normalize core lifecycle: $($_.Exception.Message)"
    }

    # 2b) Analytics segments (queues, agents, holds, transfers, etc.)
    try {
        # Typical shape: conversations[0].participants[].segments[]
        $convDetails = $analyticsDetails.conversations | Select-Object -First 1

        foreach ($participant in $convDetails.participants) {
            $participantId = $participant.participantId
            $userId = $participant.userId

            foreach ($segment in $participant.segments) {
                $start = $segment.segmentStart
                $end = $segment.segmentEnd
                $queueId = $segment.queueId

                $eventType = $segment.segmentType
                if (-not $eventType) {
                    $eventType = $segment.purpose
                }

                $extra = @{
                    Direction      = $segment.direction
                    DisconnectType = $segment.disconnectType
                    SegmentType    = $segment.segmentType
                    Purpose        = $segment.purpose
                    WrapUpCode     = $segment.wrapUpCode
                    WrapUpNote     = $segment.wrapUpNote
                    Provider       = $segment.provider
                }

                $events.Add(
                    (New-TimelineEvent `
                        -ConversationId $ConversationId `
                        -Source 'AnalyticsDetails' `
                        -EventType $eventType `
                        -StartTime ([datetime]$start) `
                        -EndTime ([datetime]$end) `
                        -QueueId $queueId `
                        -UserId $userId `
                        -ParticipantId $participantId `
                        -ExtraData $extra)
                )
            }
        }
    }
    catch {
        Write-Warning "[$ConversationId] Failed to normalize analytics segments: $($_.Exception.Message)"
    }

    # 2c) Recording metadata
    try {
        foreach ($rec in $recordingMeta) {
            $events.Add(
                (New-TimelineEvent `
                    -ConversationId $ConversationId `
                    -Source 'RecordingMetadata' `
                    -EventType 'Recording' `
                    -StartTime ([datetime]$rec.startTime) `
                    -EndTime ([datetime]$rec.endTime) `
                    -QueueId $null `
                    -UserId $rec.agentId `
                    -ParticipantId $rec.participantId `
                    -ExtraData @{
                    RecordingId = $rec.id
                    ArchiveDate = $rec.archiveDate
                    DeleteDate  = $rec.deleteDate
                })
            )
        }
    }
    catch {
        Write-Warning "[$ConversationId] Failed to normalize recording metadata: $($_.Exception.Message)"
    }

    # 2d) Sentiment points
    try {
        foreach ($s in $sentiments.sentiments) {
            $events.Add(
                (New-TimelineEvent `
                    -ConversationId $ConversationId `
                    -Source 'Sentiment' `
                    -EventType 'SentimentSample' `
                    -StartTime ([datetime]$s.timestamp) `
                    -EndTime $null `
                    -QueueId $null `
                    -UserId $s.participantId `
                    -ParticipantId $s.participantId `
                    -ExtraData @{
                    SentimentScore = $s.score
                    Channel        = $s.channel
                })
            )
        }
    }
    catch {
        Write-Warning "[$ConversationId] Failed to normalize sentiment samples: $($_.Exception.Message)"
    }

    # 2e) SIP messages
    try {
        foreach ($m in $sipMessages.entities) {
            $events.Add(
                (New-TimelineEvent `
                    -ConversationId $ConversationId `
                    -Source 'SIP' `
                    -EventType 'SipMessage' `
                    -StartTime ([datetime]$m.timestamp) `
                    -EndTime $null `
                    -QueueId $null `
                    -UserId $null `
                    -ParticipantId $null `
                    -ExtraData @{
                    Method = $m.method
                    From   = $m.from
                    To     = $m.to
                    Status = $m.status
                })
            )
        }
    }
    catch {
        Write-Warning "[$ConversationId] Failed to normalize SIP messages: $($_.Exception.Message)"
    }

    # ---------------------------------------------
    # 3) Sort timeline and return bundle
    # ---------------------------------------------
    $sortedEvents = $events |
        Sort-Object StartTime, EndTime, Source, EventType

    return [pscustomobject]@{
        ConversationId   = $ConversationId
        Core             = $coreConversation
        AnalyticsDetails = $analyticsDetails
        SpeechText       = $speechText
        RecordingMeta    = $recordingMeta
        Sentiments       = $sentiments
        SipMessages      = $sipMessages
        TimelineEvents   = $sortedEvents
    }
}
### END: Get-GCConversationTimeline
