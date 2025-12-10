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

        This is intentionally opinionated and easy to tweak for Humana's environment.

        .PARAMETER BaseUri
        Region base URI, e.g. https://api.usw2.pure.cloud

        .PARAMETER AccessToken
        OAuth Bearer token.

        .PARAMETER QueueId
        Queue ID to focus on.

        .PARAMETER Interval
        Analytics interval, e.g. 2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z

        .PARAMETER PageSize
        Max conversations to pull in one go. Start with 200 and adjust as needed.

        .PARAMETER TopN
        Number of top conversations to return by smoke score.

        .OUTPUTS
        PSCustomObject with:
          ConversationId, QueueIds, StartTime, DurationSeconds,
          ErrorSegments, ShortCalls, QueueSegments, SmokeScore
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

        # Defensive: these names are typical, but verify against real payloads and adjust.
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

        # Flatten participants/segments once
        $participants = @()
        if ($conv.participants) { $participants = $conv.participants }

        $allSegments = @()
        foreach ($p in $participants) {
            if ($p.segments) {
                $allSegments += $p.segments
            }
        }

        if (-not $allSegments -or $allSegments.Count -eq 0) {
            # Still log a row, but with zero score.
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

        # 1) Error-like disconnects: anything that isn't a normal client/endpoint hangup.
        $errorSegs = @(
            $allSegments |
                Where-Object {
                    $_.disconnectType -and
                    $_.disconnectType -notin @('client','endpoint','peer')
                }
        )
        $errorCount = $errorSegs.Count

        # 2) Very short inbound "interact" segments (customer gets in and out fast).
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
                # If anything is malformed, skip the segment instead of blowing up the conversation.
            }
        }
        $shortCount = $shortSegs.Count

        # 3) Queue segments: how many queue hops/entries?
        $queueSegs = @(
            $allSegments |
                Where-Object { $_.queueId }
        )
        $queueSegCount = $queueSegs.Count

        # Distinct queues in the call (just for reference)
        $queueIdsDistinct = @(
            $queueSegs |
                Where-Object { $_.queueId } |
                Select-Object -ExpandProperty queueId -Unique
        )
        if (-not $queueIdsDistinct -or $queueIdsDistinct.Count -eq 0) {
            $queueIdsDistinct = @($QueueId)
        }

        # Crude smoke score: tune this for your environment
        # - Error segments: 3 points each
        # - Short calls: 2 points each
        # - Queue segments: 1 point each
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

    # Rank desc by smoke score; ignore boring conversations
    $ranked = $results |
        Where-Object { $_.SmokeScore -gt 0 } |
        Sort-Object SmokeScore -Descending ErrorSegments -Descending ShortCalls -Descending |
        Select-Object -First $TopN

    return $ranked
}
### END: Get-GCQueueHotConversations
