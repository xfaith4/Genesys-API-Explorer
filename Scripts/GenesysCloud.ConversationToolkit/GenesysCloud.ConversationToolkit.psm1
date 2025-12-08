### BEGIN FILE: GenesysCloud.ConversationToolkit.psm1
# Core Genesys Cloud conversation analytics + timeline toolbox.
# This module aggregates conversation-centric scripts into a reusable module.

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
        Target conversationId.

        .OUTPUTS
        PSCustomObject with:
          - ConversationId
          - Core (GET /conversations/{id})
          - AnalyticsDetails (GET /analytics/conversations/{id}/details)
          - SpeechText
          - RecordingMeta
          - Sentiments
          - SipMessages
          - TimelineEvents (normalized list)
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

    # Local helper to keep HTTP calls consistent
    function Invoke-GCRequest {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('GET','POST','PUT','DELETE','PATCH')]
            [string]$Method,

            [Parameter(Mandatory = $true)]
            [string]$Path
        )

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

        return Invoke-RestMethod @invokeParams
    }

    Write-Verbose "Pulling core conversation for $ConversationId ..."
    $coreConversation = Invoke-GCRequest -Method 'GET' -Path "/api/v2/conversations/$ConversationId"

    Write-Verbose "Pulling analytics details for $ConversationId ..."
    $analyticsDetails = Invoke-GCRequest -Method 'GET' -Path "/api/v2/analytics/conversations/$ConversationId/details"

    Write-Verbose "Pulling speech & text analytics for $ConversationId ..."
    $speechText = $null
    try {
        $speechText = Invoke-GCRequest -Method 'GET' -Path "/api/v2/speechandtextanalytics/conversations/$ConversationId"
    }
    catch {
        Write-Verbose "Speech/Text analytics not available for $($ConversationId): $($_.Exception.Message)"
    }

    Write-Verbose "Pulling recording metadata for $ConversationId ..."
    $recordingMeta = $null
    try {
        $recordingMeta = Invoke-GCRequest -Method 'GET' -Path "/api/v2/conversations/$ConversationId/recordingmetadata"
    }
    catch {
        Write-Verbose "Recording metadata not available for $($ConversationId): $($_.Exception.Message)"
    }

    Write-Verbose "Pulling sentiment data for $ConversationId ..."
    $sentiments = $null
    try {
        $sentiments = Invoke-GCRequest -Method 'GET' -Path "/api/v2/speechandtextanalytics/conversations/$ConversationId/sentiments"
    }
    catch {
        Write-Verbose "Sentiments not available for $($ConversationId): $($_.Exception.Message)"
    }

    Write-Verbose "Pulling SIP messages for $ConversationId ..."
    $sipMessages = $null
    try {
        $sipMessages = Invoke-GCRequest -Method 'GET' -Path "/api/v2/telephony/sipmessages/conversations/$ConversationId"
    }
    catch {
        Write-Verbose "SIP messages not available for $($ConversationId): $($_.Exception.Message)"
    }

    # --- Normalize into timeline rows ----------------------------------------
    $events = [System.Collections.Generic.List[object]]::new()

    # Helper to add a timeline row
    function Add-TimelineEvent {
        param(
            [Parameter(Mandatory = $true)]
            [datetime]$StartTime,

            [Parameter(Mandatory = $false)]
            [datetime]$EndTime,

            [Parameter(Mandatory = $true)]
            [string]$Source,

            [Parameter(Mandatory = $true)]
            [string]$EventType,

            [Parameter(Mandatory = $false)]
            [string]$Participant,

            [Parameter(Mandatory = $false)]
            [string]$Queue,

            [Parameter(Mandatory = $false)]
            [string]$User,

            [Parameter(Mandatory = $false)]
            [string]$Direction,

            [Parameter(Mandatory = $false)]
            [string]$DisconnectType,

            [Parameter(Mandatory = $false)]
            [hashtable]$Extra
        )

        $events.Add([pscustomobject]@{
            ConversationId = $ConversationId
            StartTime      = $StartTime
            EndTime        = $EndTime
            Source         = $Source
            EventType      = $EventType
            Participant    = $Participant
            Queue          = $Queue
            User           = $User
            Direction      = $Direction
            DisconnectType = $DisconnectType
            Extra          = $Extra
        }) | Out-Null
    }

    # 1) Core participants/segments
    if ($coreConversation.participants) {
        foreach ($p in $coreConversation.participants) {
            $participantName = $p.name
            $userId          = $p.userId
            $queueId         = $p.queueId

            foreach ($seg in $p.segments) {
                $segStart = $null
                $segEnd   = $null

                if ($seg.segmentStart) {
                    $segStart = [datetime]$seg.segmentStart
                }
                if ($seg.segmentEnd) {
                    $segEnd = [datetime]$seg.segmentEnd
                }

                Add-TimelineEvent `
                    -StartTime $segStart `
                    -EndTime   $segEnd `
                    -Source    'Core' `
                    -EventType $seg.segmentType `
                    -Participant $participantName `
                    -Queue     $queueId `
                    -User      $userId `
                    -Direction $seg.direction `
                    -DisconnectType $seg.disconnectType `
                    -Extra ([ordered]@{
                        SegmentId     = $seg.segmentId
                        Ani           = $seg.ani
                        Dnis          = $seg.dnis
                        Purpose       = $seg.purpose
                        Conference    = $seg.conference
                        SegmentType   = $seg.segmentType
                        WrapUpCode    = $seg.wrapUpCode
                        WrapUpNote    = $seg.wrapUpNote
                        Recording     = $seg.recording
                    })
            }
        }
    }

    # 2) Analytics details - we treat each segment as an event as well
    if ($analyticsDetails.conversationId) {
        $aConv = $analyticsDetails
        if ($aConv.participants) {
            foreach ($p in $aConv.participants) {
                $participantName = $p.participantId

                foreach ($seg in $p.segments) {
                    $segStart = $null
                    $segEnd   = $null

                    if ($seg.segmentStart) {
                        $segStart = [datetime]$seg.segmentStart
                    }
                    if ($seg.segmentEnd) {
                        $segEnd = [datetime]$seg.segmentEnd
                    }

                    Add-TimelineEvent `
                        -StartTime $segStart `
                        -EndTime   $segEnd `
                        -Source    'Analytics' `
                        -EventType $seg.segmentType `
                        -Participant $participantName `
                        -Queue     $seg.queueId `
                        -User      $seg.userId `
                        -Direction $seg.direction `
                        -DisconnectType $seg.disconnectType `
                        -Extra ([ordered]@{
                            SegmentType     = $seg.segmentType
                            MediaType       = $seg.mediaType
                            FlowType        = $seg.flowType
                            FlowVersion     = $seg.flowVersion
                            Provider        = $seg.provider
                            TransferType    = $seg.transferType
                            ErrorCode       = $seg.errorCode
                            DispositionCodes = $seg.dispositionCodes
                        })
                }
            }
        }
    }

    # 3) Speech & Text analytics sections (phrases, topics, etc.)
    if ($speechText) {
        if ($speechText.conversation) {
            $convStart = $null
            if ($speechText.conversation.startTime) {
                $convStart = [datetime]$speechText.conversation.startTime
            }

            if ($speechText.conversation.topics) {
                foreach ($topic in $speechText.conversation.topics) {
                    Add-TimelineEvent `
                        -StartTime $convStart `
                        -EndTime   $null `
                        -Source    'SpeechText' `
                        -EventType 'Topic' `
                        -Participant $null `
                        -Queue     $null `
                        -User      $null `
                        -Direction $null `
                        -DisconnectType $null `
                        -Extra ([ordered]@{
                            TopicName    = $topic.name
                            TopicType    = $topic.type
                            Sentiment    = $topic.sentimentScore
                            Dialect      = $topic.dialect
                        })
                }
            }
        }
    }

    # 4) Sentiments timeline, if available
    if ($sentiments) {
        if ($sentiments.sentiment) {
            foreach ($entry in $sentiments.sentiment) {
                $time = $null
                if ($entry.time) {
                    $time = [datetime]$entry.time
                }

                Add-TimelineEvent `
                    -StartTime $time `
                    -EndTime   $null `
                    -Source    'Sentiment' `
                    -EventType 'SentimentSample' `
                    -Participant $entry.participantId `
                    -Queue     $null `
                    -User      $entry.userId `
                    -Direction $null `
                    -DisconnectType $null `
                    -Extra ([ordered]@{
                        Score = $entry.score
                        Label = $entry.label
                    })
            }
        }
    }

    # 5) Recording metadata as a coarse event
    if ($recordingMeta) {
        foreach ($rec in $recordingMeta) {
            $recStart = $null
            $recEnd   = $null

            if ($rec.startTime) {
                $recStart = [datetime]$rec.startTime
            }
            if ($rec.endTime) {
                $recEnd = [datetime]$rec.endTime
            }

            Add-TimelineEvent `
                -StartTime $recStart `
                -EndTime   $recEnd `
                -Source    'Recording' `
                -EventType 'Recording' `
                -Participant $rec.participantId `
                -Queue     $null `
                -User      $rec.agentId `
                -Direction $null `
                -DisconnectType $null `
                -Extra ([ordered]@{
                    RecordingId = $rec.id
                    ArchiveDate = $rec.archiveDate
                    DeletedDate = $rec.deleteDate
                    MediaUris   = $rec.mediaUris
                })
        }
    }

    # 6) SIP messages as low-level events
    if ($sipMessages) {
        foreach ($msg in $sipMessages) {
            $msgTime = $null
            if ($msg.timestamp) {
                $msgTime = [datetime]$msg.timestamp
            }

            Add-TimelineEvent `
                -StartTime $msgTime `
                -EndTime   $null `
                -Source    'SIP' `
                -EventType $msg.method `
                -Participant $msg.participantId `
                -Queue     $null `
                -User      $null `
                -Direction $msg.direction `
                -DisconnectType $null `
                -Extra ([ordered]@{
                    StatusCode = $msg.statusCode
                    Reason     = $msg.reasonPhrase
                    Raw        = $msg.rawMessage
                })
        }
    }

    # Sort the aggregated events by time, then by source/event type so the
    # timeline reads sensibly in a grid or export.
    $sortedEvents =
        $events |
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

### BEGIN: Get-GCQueueSmokeReport
function Get-GCQueueSmokeReport {
    <#
        .SYNOPSIS
        Produces a "smoke detector" report for queues and agents using
        conversation aggregate metrics.

        .DESCRIPTION
        Calls /api/v2/analytics/conversations/aggregates/query twice:
          - Once grouped by queueId
          - Once grouped by userId

        Computes failure indicators like:
          - AbandonRate = nAbandoned / nOffered
          - ErrorRate   = nError / nOffered (if nError is returned)
          - Average handle / talk / wait times

        Returns an object with:
          - QueueSummary   (all queues)
          - QueueTop       (top N by AbandonRate / ErrorRate)
          - AgentSummary   (all agents)
          - AgentTop       (top N by failure indicators)

        .PARAMETER BaseUri
        Region base URI, e.g. https://api.usw2.pure.cloud

        .PARAMETER AccessToken
        OAuth Bearer token.

        .PARAMETER Interval
        Analytics interval, e.g. 2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z

        .PARAMETER DivisionId
        Optional division filter.

        .PARAMETER QueueIds
        Optional list of queueIds to restrict the query.

        .PARAMETER TopN
        Number of “top” queues/agents to surface in the smoke view.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUri,

        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$Interval,

        [Parameter(Mandatory = $false)]
        [string]$DivisionId,

        [Parameter(Mandatory = $false)]
        [string[]]$QueueIds,

        [Parameter(Mandatory = $false)]
        [int]$TopN = 10
    )

    # Local helper – simple POST wrapper, same idea as in the timeline function.
    function Invoke-GCRequest {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('GET','POST','PUT','DELETE','PATCH')]
            [string]$Method,

            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $false)]
            [object]$Body
        )

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
            if ($Body -isnot [string]) {
                $invokeParams['Body']        = ($Body | ConvertTo-Json -Depth 10)
                $invokeParams['ContentType'] = 'application/json'
            }
            else {
                $invokeParams['Body']        = $Body
                $invokeParams['ContentType'] = 'application/json'
            }
        }

        return Invoke-RestMethod @invokeParams
    }

    # Base body for the aggregates query
    $baseBody = @{
        interval = $Interval
        metrics  = @(
            'nOffered',
            'nAnswered',
            'nAbandoned',
            'tHandle',
            'tTalk',
            'tWait',
            'nError'
        )
        filter   = @{
            type = 'and'
            predicates = @()
        }
        groupBy  = @()
    }

    if ($DivisionId) {
        $baseBody.filter.predicates += @{
            dimension = 'divisionId'
            value     = $DivisionId
        }
    }

    if ($QueueIds -and $QueueIds.Count -gt 0) {
        $baseBody.filter.predicates += @{
            type = 'or'
            predicates = @(
                $QueueIds | ForEach-Object {
                    @{
                        dimension = 'queueId'
                        value     = $_
                    }
                }
            )
        }
    }

    # --- Queue aggregates ----------------------------------------------------
    $queueBody = $baseBody | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $queueBody.groupBy = @('queueId')

    Write-Verbose "Requesting queue aggregates for interval $Interval ..."
    $queueAgg = Invoke-GCRequest -Method 'POST' -Path '/api/v2/analytics/conversations/aggregates/query' -Body $queueBody

    $queueRows = @()
    if ($queueAgg.results) {
        foreach ($row in $queueAgg.results) {
            $metrics = $row.data

            # Extract metrics with null checking
            $nOffered   = ($metrics | Where-Object { $_.metric -eq 'nOffered' }).statistic.sum
            $nAnswered  = ($metrics | Where-Object { $_.metric -eq 'nAnswered' }).statistic.sum
            $nAbandoned = ($metrics | Where-Object { $_.metric -eq 'nAbandoned' }).statistic.sum
            $tHandle    = ($metrics | Where-Object { $_.metric -eq 'tHandle' }).statistic.sum
            $tTalk      = ($metrics | Where-Object { $_.metric -eq 'tTalk' }).statistic.sum
            $tWait      = ($metrics | Where-Object { $_.metric -eq 'tWait' }).statistic.sum
            $nError     = ($metrics | Where-Object { $_.metric -eq 'nError' }).statistic.sum

            if (-not $nOffered) { $nOffered = 0 }
            if (-not $nAnswered) { $nAnswered = 0 }
            if (-not $nAbandoned) { $nAbandoned = 0 }
            if (-not $tHandle) { $tHandle = 0 }
            if (-not $tTalk) { $tTalk = 0 }
            if (-not $tWait) { $tWait = 0 }
            if (-not $nError) { $nError = 0 }

            $abandonRate = if ($nOffered -gt 0) { [math]::Round(($nAbandoned / $nOffered) * 100, 2) } else { 0 }
            $errorRate   = if ($nOffered -gt 0) { [math]::Round(($nError     / $nOffered) * 100, 2) } else { 0 }

            $avgHandle = if ($nAnswered -gt 0) { [math]::Round($tHandle / $nAnswered / 1000, 2) } else { 0 }
            $avgTalk   = if ($nAnswered -gt 0) { [math]::Round($tTalk   / $nAnswered / 1000, 2) } else { 0 }
            $avgWait   = if ($nOffered  -gt 0) { [math]::Round($tWait   / $nOffered  / 1000, 2) } else { 0 }

            $queueId = $row.group.queueId

            $queueRows += [pscustomobject]@{
                QueueId      = $queueId
                Offered      = $nOffered
                Answered     = $nAnswered
                Abandoned    = $nAbandoned
                Errors       = $nError
                AbandonRate  = $abandonRate
                ErrorRate    = $errorRate
                AvgHandle    = $avgHandle
                AvgTalk      = $avgTalk
                AvgWait      = $avgWait
            }
        }
    }

    # --- Agent aggregates (grouped by userId) --------------------------------
    $agentBody = $baseBody | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $agentBody.groupBy = @('userId')

    Write-Verbose "Requesting agent aggregates for interval $Interval ..."
    $agentAgg = Invoke-GCRequest -Method 'POST' -Path '/api/v2/analytics/conversations/aggregates/query' -Body $agentBody

    $agentRows = @()
    if ($agentAgg.results) {
        foreach ($row in $agentAgg.results) {
            $metrics = $row.data

            $nOffered   = ($metrics | Where-Object { $_.metric -eq 'nOffered' }).statistic.sum
            $nAnswered  = ($metrics | Where-Object { $_.metric -eq 'nAnswered' }).statistic.sum
            $nAbandoned = ($metrics | Where-Object { $_.metric -eq 'nAbandoned' }).statistic.sum
            $tHandle    = ($metrics | Where-Object { $_.metric -eq 'tHandle' }).statistic.sum
            $tTalk      = ($metrics | Where-Object { $_.metric -eq 'tTalk' }).statistic.sum
            $tWait      = ($metrics | Where-Object { $_.metric -eq 'tWait' }).statistic.sum
            $nError     = ($metrics | Where-Object { $_.metric -eq 'nError' }).statistic.sum

            if (-not $nOffered) { $nOffered = 0 }
            if (-not $nAnswered) { $nAnswered = 0 }
            if (-not $nAbandoned) { $nAbandoned = 0 }
            if (-not $tHandle) { $tHandle = 0 }
            if (-not $tTalk) { $tTalk = 0 }
            if (-not $tWait) { $tWait = 0 }
            if (-not $nError) { $nError = 0 }

            $abandonRate = if ($nOffered -gt 0) { [math]::Round(($nAbandoned / $nOffered) * 100, 2) } else { 0 }
            $errorRate   = if ($nOffered -gt 0) { [math]::Round(($nError     / $nOffered) * 100, 2) } else { 0 }

            $avgHandle = if ($nAnswered -gt 0) { [math]::Round($tHandle / $nAnswered / 1000, 2) } else { 0 }
            $avgTalk   = if ($nAnswered -gt 0) { [math]::Round($tTalk   / $nAnswered / 1000, 2) } else { 0 }
            $avgWait   = if ($nOffered  -gt 0) { [math]::Round($tWait   / $nOffered  / 1000, 2) } else { 0 }

            $userId = $row.group.userId

            $agentRows += [pscustomobject]@{
                UserId       = $userId
                Offered      = $nOffered
                Answered     = $nAnswered
                Abandoned    = $nAbandoned
                Errors       = $nError
                AbandonRate  = $abandonRate
                ErrorRate    = $errorRate
                AvgHandle    = $avgHandle
                AvgTalk      = $avgTalk
                AvgWait      = $avgWait
            }
        }
    }

    # Rank top queues/agents by "badness" – high abandon, high error, etc.
    $queueTop =
        $queueRows |
        Sort-Object @{Expression = 'AbandonRate'; Descending = $true},
                    @{Expression = 'ErrorRate';   Descending = $true},
                    @{Expression = 'Offered';     Descending = $true} |
        Select-Object -First $TopN

    $agentTop =
        $agentRows |
        Sort-Object @{Expression = 'AbandonRate'; Descending = $true},
                    @{Expression = 'ErrorRate';   Descending = $true},
                    @{Expression = 'Offered';     Descending = $true} |
        Select-Object -First $TopN

    return [pscustomobject]@{
        Interval     = $Interval
        QueueSummary = $queueRows
        QueueTop     = $queueTop
        AgentSummary = $agentRows
        AgentTop     = $agentTop
    }
}
### END: Get-GCQueueSmokeReport

### BEGIN: Get-GCQueueHotConversations
function Get-GCQueueHotConversations {
    <#
        .SYNOPSIS
        For a given queue and interval, find the "hottest" / most suspicious conversations.

        .DESCRIPTION
        Uses /api/v2/analytics/conversations/details/query with:
          - interval
          - conversationFilters on queueId
          - a single page of results (tune pageSize for your environment)

        Then inspects participants.segments and computes a crude "smoke score" per conversation:
          - error-like disconnectTypes (non-client, non-endpoint) are weighted heavily
          - very short inbound interactions get a smaller weight
          - multiple queue hops / segments add a small weight

        This is intentionally opinionated and easy to tweak for your environment.

        .PARAMETER BaseUri
        Region base URI, e.g. https://api.usw2.pure.cloud

        .PARAMETER AccessToken
        OAuth Bearer token.

        .PARAMETER QueueId
        Queue ID to focus on.

        .PARAMETER Interval
        Analytics interval.

        .PARAMETER PageSize
        Max conversations to pull.

        .PARAMETER TopN
        Number of hottest conversations to return.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseUri,

        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$QueueId,

        [Parameter(Mandatory = $true)]
        [string]$Interval,

        [Parameter(Mandatory = $false)]
        [int]$PageSize = 200,

        [Parameter(Mandatory = $false)]
        [int]$TopN = 25
    )

    # Local helper: simple JSON POST wrapper.
    function Invoke-GCRequest {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateSet('GET','POST','PUT','DELETE','PATCH')]
            [string]$Method,

            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $false)]
            [object]$Body
        )

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
            if ($Body -isnot [string]) {
                $invokeParams['Body']        = ($Body | ConvertTo-Json -Depth 10)
                $invokeParams['ContentType'] = 'application/json'
            }
            else {
                $invokeParams['Body']        = $Body
                $invokeParams['ContentType'] = 'application/json'
            }
        }

        return Invoke-RestMethod @invokeParams
    }

    # Build the details query body based on the queue + interval
    $body = @{
        interval = $Interval
        order    = 'asc'
        orderBy  = 'conversationStart'
        paging   = @{
            pageSize   = $PageSize
            pageNumber = 1
        }
        conversationFilters = @(
            @{
                type = 'or'
                predicates = @(
                    @{
                        dimension = 'queueId'
                        value     = $QueueId
                    }
                )
            }
        )
        segmentFilters = @()
    }

    Write-Verbose "Requesting conversation details for queue $QueueId, interval $Interval ..."
    $details = Invoke-GCRequest -Method 'POST' -Path '/api/v2/analytics/conversations/details/query' -Body $body

    if (-not $details -or -not $details.conversations) {
        Write-Verbose "No conversations returned for queue $QueueId in interval $Interval."
        return @()
    }

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($conv in $details.conversations) {
        $convId = $conv.conversationId

        $start = $conv.conversationStart
        $end   = $conv.conversationEnd

        $startDt = $null
        $endDt   = $null

        if ($start) { $startDt = [datetime]$start }
        if ($end)   { $endDt   = [datetime]$end }

        $durationSec = $null
        if ($startDt -and $endDt -and $endDt -gt $startDt) {
            $durationSec = [int]([TimeSpan]::op_Subtraction($endDt, $startDt).TotalSeconds)
        }

        $participants = @()
        if ($conv.participants) { $participants = $conv.participants }

        $allSegments = @()
        foreach ($p in $participants) {
            if ($p.segments) {
                $allSegments += $p.segments
            }
        }

        if (-not $allSegments -or $allSegments.Count -eq 0) {
            $results.Add([pscustomobject]@{
                ConversationId   = $convId
                QueueIds         = @($QueueId)
                StartTime        = $startDt
                DurationSeconds  = $durationSec
                ErrorSegments    = 0
                ShortCalls       = 0
                QueueSegments    = 0
                SmokeScore       = 0
            })
            continue
        }

        # Error-like disconnects: anything that isn't a normal client/endpoint hangup.
        $errorSegs = @(
            $allSegments |
                Where-Object {
                    $_.disconnectType -and
                    $_.disconnectType -notin @('client','endpoint','peer')
                }
        )
        $errorCount = $errorSegs.Count

        # Very short inbound "interact" segments (customer gets in and out fast).
        $shortSegs = @()
        foreach ($seg in $allSegments) {
            try {
                $segStart = $seg.segmentStart
                $segEnd   = $seg.segmentEnd

                if (-not $segStart -or -not $segEnd) { continue }

                $sd = [datetime]$segStart
                $ed = [datetime]$segEnd

                $segDuration = [TimeSpan]::op_Subtraction($ed, $sd).TotalSeconds

                if ($seg.segmentType -eq 'interact' -and
                    $seg.direction  -eq 'inbound'  -and
                    $segDuration -lt 15) {
                    $shortSegs += $seg
                }
            }
            catch {
                # Skip malformed segments
            }
        }
        $shortCount = $shortSegs.Count

        # Queue segments: how many queue hops/entries?
        $queueSegs = @(
            $allSegments |
                Where-Object { $_.queueId }
        )
        $queueSegCount = $queueSegs.Count

        $queueIdsDistinct = @(
            $queueSegs |
                Where-Object { $_.queueId } |
                Select-Object -ExpandProperty queueId -Unique
        )
        if (-not $queueIdsDistinct -or $queueIdsDistinct.Count -eq 0) {
            $queueIdsDistinct = @($QueueId)
        }

        # Crude smoke score: tune this for your environment
        $smokeScore =
            ($errorCount * 3) +
            ($shortCount * 2) +
            ($queueSegCount * 1)

        $results.Add([pscustomobject]@{
            ConversationId   = $convId
            QueueIds         = $queueIdsDistinct
            StartTime        = $startDt
            DurationSeconds  = $durationSec
            ErrorSegments    = $errorCount
            ShortCalls       = $shortCount
            QueueSegments    = $queueSegCount
            SmokeScore       = $smokeScore
        })
    }

    $ranked = $results |
        Where-Object { $_.SmokeScore -gt 0 } |
        Sort-Object SmokeScore -Descending ErrorSegments -Descending ShortCalls -Descending |
        Select-Object -First $TopN

    return $ranked
}
### END: Get-GCQueueHotConversations

function Show-GCConversationTimelineUI {
### BEGIN FILE: Show-GCConversationTimelineUI.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUri,

    [Parameter(Mandatory = $true)]
    [string]$AccessToken,

    # Optional: preload and auto-load this conversation on open
    [Parameter(Mandatory = $false)]
    [string]$ConversationId
)

# Ensure the timeline function is available
if (-not (Get-Command -Name Get-GCConversationTimeline -ErrorAction SilentlyContinue)) {
    throw "Get-GCConversationTimeline is not available. Import your Genesys toolbox module before running this UI."
}

# WPF assemblies
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase

# Simple WPF layout: input row + grid + status bar
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Genesys Cloud Conversation Timeline"
        Height="600" Width="1000"
        WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,8">
      <TextBlock Text="Conversation ID:" VerticalAlignment="Center" Margin="0,0,4,0"/>
      <TextBox x:Name="ConversationIdBox" Width="300" Margin="0,0,8,0"/>
      <Button x:Name="LoadButton" Content="Load" Width="80" Margin="0,0,8,0"/>
      <TextBlock Text="Base URI:" VerticalAlignment="Center" Margin="16,0,4,0"/>
      <TextBox x:Name="BaseUriBox" Width="260" Margin="0,0,8,0"/>
    </StackPanel>

    <DataGrid x:Name="TimelineGrid"
              Grid.Row="1"
              AutoGenerateColumns="True"
              IsReadOnly="True"
              CanUserAddRows="False"
              CanUserDeleteRows="False"
              Margin="0,0,0,4" />

    <TextBlock x:Name="StatusText"
               Grid.Row="2"
               Margin="0,4,0,0"
               TextWrapping="Wrap"
               Foreground="Gray" />
  </Grid>
</Window>
"@

# Parse XAML into WPF objects
[xml]$xamlXml = $xaml
$reader      = New-Object System.Xml.XmlNodeReader $xamlXml
$window      = [Windows.Markup.XamlReader]::Load($reader)

# Grab controls we care about
$conversationIdBox = $window.FindName('ConversationIdBox')
$loadButton        = $window.FindName('LoadButton')
$baseUriBox        = $window.FindName('BaseUriBox')
$timelineGrid      = $window.FindName('TimelineGrid')
$statusText        = $window.FindName('StatusText')

# Seed the BaseUri so you don't retype it every time
$baseUriBox.Text = $BaseUri

# Seed ConversationId if we were given one
if ($ConversationId) {
    $conversationIdBox.Text = $ConversationId
}

# Core handler that loads the timeline
$loadHandler = {
    try {
        $convId = $conversationIdBox.Text.Trim()
        $base   = $baseUriBox.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($convId)) {
            $statusText.Text = "Please enter a Conversation ID."
            return
        }

        if ([string]::IsNullOrWhiteSpace($base)) {
            $statusText.Text = "Please enter a Base URI."
            return
        }

        $statusText.Text = "Loading conversation $convId ..."
        $window.Cursor   = [System.Windows.Input.Cursors]::Wait

        $bundle = Get-GCConversationTimeline -BaseUri $base -AccessToken $AccessToken -ConversationId $convId -Verbose:$false

        if (-not $bundle) {
            $statusText.Text = "No data returned for conversation $convId."
            $timelineGrid.ItemsSource = $null
            return
        }

        $timelineGrid.ItemsSource = $bundle.TimelineEvents

        $count = if ($bundle.TimelineEvents) { $bundle.TimelineEvents.Count } else { 0 }
        $statusText.Text = "Loaded $count events for conversation $convId."
    }
    catch {
        $statusText.Text = "Error loading conversation: $($_.Exception.Message)"
    }
    finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
}

# Wire up button click
$loadButton.Add_Click($loadHandler)

# Allow hitting Enter in the ConversationId box to trigger load
$conversationIdBox.Add_KeyDown({
    param($sender,$e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        & $loadHandler
    }
})

# If we got a ConversationId param, auto-load it when the window shows
if ($ConversationId) {
    $window.Add_Loaded({
        & $loadHandler
    })
}

# Show the WPF window modally
$window.ShowDialog() | Out-Null
### END FILE: Show-GCConversationTimelineUI.ps1
}

function Invoke-GCSmokeDrill {
### BEGIN FILE: Invoke-GCSmokeDrill.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUri,

    [Parameter(Mandatory = $true)]
    [string]$AccessToken,

    [Parameter(Mandatory = $true)]
    [string]$Interval,

    [Parameter(Mandatory = $false)]
    [string]$DivisionId,

    [Parameter(Mandatory = $false)]
    [string[]]$QueueIds,

    [Parameter(Mandatory = $false)]
    [int]$TopNQueues = 10,

    [Parameter(Mandatory = $false)]
    [int]$TopNConversations = 25,

    # Path to your WPF timeline UI script or function
    [Parameter(Mandatory = $false)]
    [string]$TimelineScriptPath = "Show-GCConversationTimelineUI"
)

# Quick sanity checks so we fail early instead of silently doing nothing.
foreach ($fn in 'Get-GCQueueSmokeReport','Get-GCQueueHotConversations') {
    if (-not (Get-Command -Name $fn -ErrorAction SilentlyContinue)) {
        throw "Required function '$fn' is not available. Import your Genesys toolbox module first."
    }
}

# Allow either a function name or a script path for the timeline UI.
if (-not (Get-Command -Name $TimelineScriptPath -ErrorAction SilentlyContinue) -and
    -not (Test-Path -LiteralPath $TimelineScriptPath)) {
    throw "Timeline UI '$($TimelineScriptPath)' not found as a function or script."
}

# 1) Produce smoke report (queues/agents)
Write-Host "Generating queue smoke report for interval $Interval ..." -ForegroundColor Cyan

$report = Get-GCQueueSmokeReport `
    -BaseUri $BaseUri `
    -AccessToken $AccessToken `
    -Interval $Interval `
    -DivisionId $DivisionId `
    -QueueIds $QueueIds `
    -TopN $TopNQueues

if (-not $report -or -not $report.QueueTop) {
    Write-Warning "No queue data returned. Nothing to drill into."
    return
}

# 2) Let you pick a queue via Out-GridView (double-click to select)
$queueView = $report.QueueTop |
    Select-Object QueueName, QueueId, Offered, Abandoned, AbandonRate, ErrorRate, AvgHandle, AvgWait |
    Out-GridView -Title "Queue Smoke Report (double-click a queue to drill)" -PassThru

if (-not $queueView) {
    Write-Host "No queue selected. Exiting."
    return
}

$selectedQueueId   = $queueView.QueueId
$selectedQueueName = $queueView.QueueName

Write-Host "Selected queue: $selectedQueueName [$selectedQueueId]" -ForegroundColor Yellow

# 3) Get hot conversations for that queue
$hotConvs = Get-GCQueueHotConversations `
    -BaseUri $BaseUri `
    -AccessToken $AccessToken `
    -QueueId $selectedQueueId `
    -Interval $Interval `
    -TopN $TopNConversations

if (-not $hotConvs -or $hotConvs.Count -eq 0) {
    Write-Warning "No 'hot' conversations detected for $selectedQueueName in $Interval."
    return
}

# Present a trimmed grid of the suspicious conversations.
$convView = $hotConvs |
    Select-Object ConversationId, SmokeScore, ErrorSegments, ShortCalls, QueueSegments, StartTime, DurationSeconds, QueueIds |
    Out-GridView -Title "Hot Conversations for $selectedQueueName (double-click to open timeline)" -PassThru

if (-not $convView) {
    Write-Host "No conversation selected. Exiting."
    return
}

$selectedConvId = $convView.ConversationId
Write-Host "Opening timeline for conversation $selectedConvId ..." -ForegroundColor Yellow

# 4) Launch the WPF UI, preloading the conversationID
#    We pass BaseUri, AccessToken, and ConversationId so the window opens ready to go.
& $TimelineScriptPath `
    -BaseUri $BaseUri `
    -AccessToken $AccessToken `
    -ConversationId $selectedConvId
### END FILE: Invoke-GCSmokeDrill.ps1
}

### END FILE: GenesysCloud.ConversationToolkit.psm1
