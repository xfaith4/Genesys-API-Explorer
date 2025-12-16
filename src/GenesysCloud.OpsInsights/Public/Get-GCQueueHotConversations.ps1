### BEGIN FILE: Public\Get-GCQueueHotConversations.ps1
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
        [Parameter()]
        [string]$BaseUri,

        [Parameter()]
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

    # Resolve connection details from either explicit parameters or Connect-GCCloud context
    $auth = Resolve-GCAuth -BaseUri $BaseUri -AccessToken $AccessToken
    $BaseUri = $auth.BaseUri
    $AccessToken = $auth.AccessToken


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
    $details = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'POST' -Path '/api/v2/analytics/conversations/details/query' -Body $body

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
### END FILE: Public\Get-GCQueueHotConversations.ps1
