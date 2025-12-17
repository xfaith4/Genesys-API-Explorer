### BEGIN FILE: Public\Get-GCRoutingStatusReport.ps1
function Get-GCRoutingStatusReport {
    <#
        .SYNOPSIS
        Produces a routing status duration report from conversation details,
        tracking time spent in each routing status (e.g., "Not Responding").

        .DESCRIPTION
        Calls /api/v2/analytics/conversations/details/query to fetch segment-level
        data, then extracts and aggregates routing status durations.

        Computes metrics for each routing status:
          - Total duration in status (seconds)
          - Count of segments with this status
          - Average duration per segment
          - Can be grouped by queue, division, or agent

        Returns an object with:
          - RoutingStatusSummary (all statuses across all groups)
          - GroupedByQueue       (if grouping by queue)
          - GroupedByDivision    (if grouping by division)
          - GroupedByAgent       (if grouping by agent)

        .PARAMETER BaseUri
        Region base URI, e.g. https://api.usw2.pure.cloud

        .PARAMETER AccessToken
        OAuth Bearer token.

        .PARAMETER Interval
        Analytics interval, e.g. 2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z

        .PARAMETER GroupBy
        Dimension to group results: 'queue', 'division', 'agent', or 'none'

        .PARAMETER QueueIds
        Optional list of queueIds to restrict the query.

        .PARAMETER DivisionId
        Optional division filter.

        .PARAMETER PageSize
        Number of conversations per page (default 100, max 100)

        .PARAMETER MaxPages
        Maximum pages to retrieve (default 10 to prevent runaway queries)

        .EXAMPLE
        Get-GCRoutingStatusReport -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' -GroupBy 'queue'
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BaseUri,

        [Parameter()]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$Interval,

        [Parameter(Mandatory = $false)]
        [ValidateSet('queue','division','agent','none')]
        [string]$GroupBy = 'none',

        [Parameter(Mandatory = $false)]
        [string[]]$QueueIds,

        [Parameter(Mandatory = $false)]
        [string]$DivisionId,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$PageSize = 100,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$MaxPages = 10
    )

    # Resolve connection details from either explicit parameters or Connect-GCCloud context
    $auth = Resolve-GCAuth -BaseUri $BaseUri -AccessToken $AccessToken
    $BaseUri = $auth.BaseUri
    $AccessToken = $auth.AccessToken

    # Build conversation details query
    $queryBody = @{
        interval = $Interval
        order    = 'asc'
        orderBy  = 'conversationStart'
        paging   = @{
            pageSize   = $PageSize
            pageNumber = 1
        }
        segmentFilters = @(
            @{
                type = 'and'
                predicates = @(
                    @{
                        dimension = 'purpose'
                        value     = 'agent'
                    }
                )
            }
        )
        conversationFilters = @()
    }

    # Add optional filters
    if ($QueueIds -and $QueueIds.Count -gt 0) {
        $queueFilter = @{
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
        $queryBody.conversationFilters += $queueFilter
    }

    if ($DivisionId) {
        $queryBody.conversationFilters += @{
            dimension = 'divisionId'
            value     = $DivisionId
        }
    }

    # Initialize aggregation storage
    $routingStatusData = @{}
    $totalConversations = 0
    $pageNumber = 1

    Write-Verbose "Fetching conversation details for routing status analysis..."

    # Paginate through conversation details
    while ($pageNumber -le $MaxPages) {
        $queryBody.paging.pageNumber = $pageNumber
        
        Write-Verbose "Fetching page $pageNumber..."
        $response = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'POST' -Path '/api/v2/analytics/conversations/details/query' -Body $queryBody

        if (-not $response.conversations -or $response.conversations.Count -eq 0) {
            Write-Verbose "No more conversations found."
            break
        }

        $totalConversations += $response.conversations.Count

        # Process each conversation
        foreach ($conversation in $response.conversations) {
            # Extract grouping key
            $groupKey = switch ($GroupBy) {
                'queue'    { 
                    $queueId = ($conversation.participants | Where-Object { $_.sessions } | 
                               Select-Object -First 1 -ExpandProperty sessions | 
                               Where-Object { $_.segments } |
                               Select-Object -First 1 -ExpandProperty segments |
                               Where-Object { $_.queueId } |
                               Select-Object -First 1 -ExpandProperty queueId)
                    if ($queueId) { $queueId } else { 'Unknown' }
                }
                'division' { 
                    $divId = $conversation.divisionIds | Select-Object -First 1
                    if ($divId) { $divId } else { 'Unknown' }
                }
                'agent'    { 
                    $userId = ($conversation.participants | Where-Object { $_.purpose -eq 'agent' } | 
                               Select-Object -First 1 -ExpandProperty userId)
                    if ($userId) { $userId } else { 'Unknown' }
                }
                default    { 'Overall' }
            }

            # Initialize group if needed
            if (-not $routingStatusData.ContainsKey($groupKey)) {
                $routingStatusData[$groupKey] = @{}
            }

            # Process segments for routing status
            foreach ($participant in $conversation.participants) {
                if ($participant.purpose -eq 'agent' -and $participant.sessions) {
                    foreach ($session in $participant.sessions) {
                        if ($session.segments) {
                            foreach ($segment in $session.segments) {
                                # Extract routing status if available
                                $routingStatus = $segment.properties.routingStatus
                                
                                if ($routingStatus) {
                                    # Initialize status tracking
                                    if (-not $routingStatusData[$groupKey].ContainsKey($routingStatus)) {
                                        $routingStatusData[$groupKey][$routingStatus] = @{
                                            TotalDurationMs = 0
                                            SegmentCount    = 0
                                        }
                                    }

                                    # Calculate segment duration
                                    if ($segment.segmentStart -and $segment.segmentEnd) {
                                        $start = [DateTime]::Parse($segment.segmentStart)
                                        $end = [DateTime]::Parse($segment.segmentEnd)
                                        $durationMs = ($end - $start).TotalMilliseconds

                                        $routingStatusData[$groupKey][$routingStatus].TotalDurationMs += $durationMs
                                        $routingStatusData[$groupKey][$routingStatus].SegmentCount += 1
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        # Check if there are more pages
        if ($response.conversations.Count -lt $PageSize) {
            Write-Verbose "Reached last page."
            break
        }

        $pageNumber++
    }

    Write-Verbose "Processed $totalConversations conversations across $($pageNumber - 1) pages."

    # Build summary report
    $summaryRows = @()
    $groupedResults = @{}

    foreach ($groupKey in $routingStatusData.Keys) {
        $groupedResults[$groupKey] = @()
        
        foreach ($status in $routingStatusData[$groupKey].Keys) {
            $data = $routingStatusData[$groupKey][$status]
            $totalDurationSec = [math]::Round($data.TotalDurationMs / 1000, 2)
            $avgDurationSec = if ($data.SegmentCount -gt 0) { 
                [math]::Round($data.TotalDurationMs / $data.SegmentCount / 1000, 2) 
            } else { 0 }

            $row = [pscustomobject]@{
                GroupKey          = $groupKey
                RoutingStatus     = $status
                SegmentCount      = $data.SegmentCount
                TotalDurationSec  = $totalDurationSec
                AvgDurationSec    = $avgDurationSec
            }

            $summaryRows += $row
            $groupedResults[$groupKey] += $row
        }
    }

    # Build return object based on grouping
    $result = @{
        Interval               = $Interval
        GroupBy                = $GroupBy
        TotalConversations     = $totalConversations
        RoutingStatusSummary   = $summaryRows
    }

    if ($GroupBy -eq 'queue') {
        $result.GroupedByQueue = $groupedResults
    }
    elseif ($GroupBy -eq 'division') {
        $result.GroupedByDivision = $groupedResults
    }
    elseif ($GroupBy -eq 'agent') {
        $result.GroupedByAgent = $groupedResults
    }

    return [pscustomobject]$result
}
### END FILE: Public\Get-GCRoutingStatusReport.ps1
