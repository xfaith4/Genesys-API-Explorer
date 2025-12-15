### BEGIN FILE: Public\Get-GCQueueSmokeReport.ps1
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
        [Parameter()]
        [string]$BaseUri,

        [Parameter()]
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

    # Resolve connection details from either explicit parameters or Connect-GCCloud context
    $auth = Resolve-GCAuth -BaseUri $BaseUri -AccessToken $AccessToken
    $BaseUri = $auth.BaseUri
    $AccessToken = $auth.AccessToken


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
    $queueAgg = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'POST' -Path '/api/v2/analytics/conversations/aggregates/query' -Body $queueBody

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
    $agentAgg = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'POST' -Path '/api/v2/analytics/conversations/aggregates/query' -Body $agentBody

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
### END FILE: Public\Get-GCQueueSmokeReport.ps1
