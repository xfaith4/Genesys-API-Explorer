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

        Returns top N queues and agents by AbandonRate (and ErrorRate).

        .PARAMETER BaseUri
        API base URI, e.g. https://api.usw2.pure.cloud

        .PARAMETER AccessToken
        OAuth Bearer token.

        .PARAMETER Interval
        Analytics interval string, e.g. "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z"

        .PARAMETER DivisionId
        Optional Division filter.

        .PARAMETER QueueIds
        Optional list of queue IDs to focus on.

        .PARAMETER TopN
        Number of top queues/agents to return (default 10).
        .EXAMPLE
        $report = Get-GCQueueSmokeReport `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -AccessToken $token `
    -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' `
    -DivisionId 'division-id-goes-here' `
    -TopN 10

$report.QueueTop  | Format-Table QueueName, Offered, Abandoned, AbandonRate, ErrorRate -Auto
$report.AgentTop  | Format-Table UserName, Offered, Abandoned, AbandonRate, ErrorRate -Auto

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

    # Helper: build the Analytics filter based on Division + QueueIds.
    function New-ConversationFilter {
        param(
            [string]  $DivisionId,
            [string[]]$QueueIds
        )

        $predicates = @()

        if ($DivisionId) {
            $predicates += @{
                type      = 'predicate'
                dimension = 'divisionId'
                operator  = 'matches'
                value     = $DivisionId
            }
        }

        if ($QueueIds -and $QueueIds.Count -gt 0) {
            $predicates += @{
                type      = 'predicate'
                dimension = 'queueId'
                operator  = 'in'
                values    = $QueueIds
            }
        }

        if ($predicates.Count -eq 0) {
            # No filter – everything in the interval.
            return $null
        }

        return @{
            type       = 'and'
            predicates = $predicates
        }
    }

    # Helper: turn a result.data[] array into a simple metric hashtable
    function Get-MetricMap {
        param(
            [Parameter(Mandatory = $true)]
            $DataArray
        )

        $map = @{}
        foreach ($d in $DataArray) {
            $metricName = $d.metric
            if (-not $metricName) { continue }

            $value = $null

            # Genesys stats often expose count/sum; we pick count first then sum as fallback.
            if ($d.stats) {
                if ($null -ne $d.stats.count) {
                    $value = [double]$d.stats.count
                }
                elseif ($null -ne $d.stats.sum) {
                    $value = [double]$d.stats.sum
                }
            }

            $map[$metricName] = $value
        }

        return $map
    }

    # ---------------------------------------------
    # 1) Queue-level aggregates
    # ---------------------------------------------
    $filter = New-ConversationFilter -DivisionId $DivisionId -QueueIds $QueueIds

    $queueAggBody = @{
        interval = $Interval
        groupBy  = @('queueId')
        metrics  = @('nOffered','nHandled','nAbandoned','tHandle','tTalk','tWait','nError')
    }

    if ($filter) {
        $queueAggBody['filter'] = $filter
    }

    Write-Verbose "Requesting queue-level aggregates for interval $Interval ..."
    $queueAggResp = Invoke-GCRequest -Method 'POST' -Path '/api/v2/analytics/conversations/aggregates/query' -Body $queueAggBody

    $queueRows = [System.Collections.Generic.List[object]]::new()

    foreach ($r in $queueAggResp.results) {
        $group = $r.group
        $metrics = Get-MetricMap -DataArray $r.data

        $queueId   = $group.queueId
        $offered   = [double]($metrics['nOffered']   | ForEach-Object { $_ })  # avoid null unboxing weirdness
        $abandoned = [double]($metrics['nAbandoned'] | ForEach-Object { $_ })
        $handled   = [double]($metrics['nHandled']   | ForEach-Object { $_ })

        if (-not $offered) { $offered = 0.0 }
        if (-not $abandoned) { $abandoned = 0.0 }
        if (-not $handled) { $handled = 0.0 }

        $abandonRate = if ($offered -gt 0) { $abandoned / $offered } else { 0.0 }

        $nError = 0.0
        if ($metrics.ContainsKey('nError') -and $metrics['nError'] -ne $null) {
            $nError = [double]$metrics['nError']
        }
        $errorRate = if ($offered -gt 0) { $nError / $offered } else { 0.0 }

        # NOTE: Duration metrics (tHandle, tTalk, tWait) might be in ms – verify in your tenant.
        $tHandle = [double]($metrics['tHandle'] | ForEach-Object { $_ })
        $tTalk   = [double]($metrics['tTalk']   | ForEach-Object { $_ })
        $tWait   = [double]($metrics['tWait']   | ForEach-Object { $_ })

        $avgHandle = if ($handled -gt 0 -and $tHandle -gt 0) { $tHandle / $handled } else { $null }
        $avgTalk   = if ($handled -gt 0 -and $tTalk   -gt 0) { $tTalk   / $handled } else { $null }
        $avgWait   = if ($offered -gt 0 -and $tWait   -gt 0) { $tWait   / $offered } else { $null }

        $queueRows.Add([pscustomobject]@{
            QueueId         = $queueId
            Offered         = [int][math]::Round($offered,0)
            Handled         = [int][math]::Round($handled,0)
            Abandoned       = [int][math]::Round($abandoned,0)
            AbandonRate     = $abandonRate
            ErrorCount      = [int][math]::Round($nError,0)
            ErrorRate       = $errorRate
            AvgHandle       = $avgHandle
            AvgTalk         = $avgTalk
            AvgWait         = $avgWait
        })
    }

    # Rank queues by AbandonRate then ErrorRate, but ignore queues with tiny volume
    $queueTop = $queueRows |
        Where-Object { $_.Offered -ge 20 } |   # tune this threshold to your liking
        Sort-Object AbandonRate, ErrorRate -Descending |
        Select-Object -First $TopN

    # Optionally resolve queue names for readability
    foreach ($q in $queueTop) {
        try {
            $queue = Invoke-GCRequest -Method 'GET' -Path "/api/v2/routing/queues/$($q.QueueId)"
            $q | Add-Member -NotePropertyName 'QueueName' -NotePropertyValue $queue.name -Force
        }
        catch {
            # If we fail to resolve, leave only the ID – don't kill the report.
            Write-Verbose "Failed to resolve queue name for $($q.QueueId): $($_.Exception.Message)"
        }
    }

    # ---------------------------------------------
    # 2) Agent-level aggregates (userId)
    # ---------------------------------------------

    $agentAggBody = @{
        interval = $Interval
        groupBy  = @('userId')
        metrics  = @('nOffered','nHandled','nAbandoned','tHandle','tTalk','tWait','nError')
    }

    if ($filter) {
        $agentAggBody['filter'] = $filter
    }

    Write-Verbose "Requesting agent-level aggregates for interval $Interval ..."
    $agentAggResp = Invoke-GCRequest -Method 'POST' -Path '/api/v2/analytics/conversations/aggregates/query' -Body $agentAggBody

    $agentRows = [System.Collections.Generic.List[object]]::new()

    foreach ($r in $agentAggResp.results) {
        $group   = $r.group
        $metrics = Get-MetricMap -DataArray $r.data

        $userId   = $group.userId
        $offered  = [double]($metrics['nOffered']   | ForEach-Object { $_ })
        $abandoned = [double]($metrics['nAbandoned'] | ForEach-Object { $_ })
        $handled   = [double]($metrics['nHandled']   | ForEach-Object { $_ })

        if (-not $offered) { $offered = 0.0 }
        if (-not $abandoned) { $abandoned = 0.0 }
        if (-not $handled) { $handled = 0.0 }

        $abandonRate = if ($offered -gt 0) { $abandoned / $offered } else { 0.0 }

        $nError = 0.0
        if ($metrics.ContainsKey('nError') -and $metrics['nError'] -ne $null) {
            $nError = [double]$metrics['nError']
        }
        $errorRate = if ($offered -gt 0) { $nError / $offered } else { 0.0 }

        $tHandle = [double]($metrics['tHandle'] | ForEach-Object { $_ })
        $tTalk   = [double]($metrics['tTalk']   | ForEach-Object { $_ })
        $tWait   = [double]($metrics['tWait']   | ForEach-Object { $_ })

        $avgHandle = if ($handled -gt 0 -and $tHandle -gt 0) { $tHandle / $handled } else { $null }
        $avgTalk   = if ($handled -gt 0 -and $tTalk   -gt 0) { $tTalk   / $handled } else { $null }
        $avgWait   = if ($offered -gt 0 -and $tWait   -gt 0) { $tWait   / $offered } else { $null }

        $agentRows.Add([pscustomobject]@{
            UserId          = $userId
            Offered         = [int][math]::Round($offered,0)
            Handled         = [int][math]::Round($handled,0)
            Abandoned       = [int][math]::Round($abandoned,0)
            AbandonRate     = $abandonRate
            ErrorCount      = [int][math]::Round($nError,0)
            ErrorRate       = $errorRate
            AvgHandle       = $avgHandle
            AvgTalk         = $avgTalk
            AvgWait         = $avgWait
        })
    }

    $agentTop = $agentRows |
        Where-Object { $_.Offered -ge 20 } |
        Sort-Object AbandonRate, ErrorRate -Descending |
        Select-Object -First $TopN

    # Resolve user names for readability
    foreach ($a in $agentTop) {
        try {
            $user = Invoke-GCRequest -Method 'GET' -Path "/api/v2/users/$($a.UserId)"
            $a | Add-Member -NotePropertyName 'UserName' -NotePropertyValue $user.name -Force
        }
        catch {
            Write-Verbose "Failed to resolve user name for $($a.UserId): $($_.Exception.Message)"
        }
    }

    # ---------------------------------------------
    # 3) Return combined smoke report
    # ---------------------------------------------
    return [pscustomobject]@{
        Interval   = $Interval
        DivisionId = $DivisionId
        QueueIds   = $QueueIds
        QueueTop   = $queueTop
        AgentTop   = $agentTop
    }
}
### END: Get-GCQueueSmokeReport
