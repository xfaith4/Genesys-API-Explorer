### BEGIN FILE: Public\Get-GCDivisionReport.ps1
function Get-GCDivisionReport {
    <#
        .SYNOPSIS
        Produces a division-level conversation aggregation report with abandon rates
        and key performance metrics.

        .DESCRIPTION
        Calls /api/v2/analytics/conversations/aggregates/query grouped by divisionId
        to compute division-level statistics including:
          - AbandonRate = nAbandoned / nOffered
          - ErrorRate   = nError / nOffered
          - Average handle / talk / wait times
          - Call volume (offered, answered)

        Returns an object with:
          - DivisionSummary (all divisions)
          - DivisionTop     (top N by AbandonRate / ErrorRate)

        .PARAMETER BaseUri
        Region base URI, e.g. https://api.usw2.pure.cloud

        .PARAMETER AccessToken
        OAuth Bearer token.

        .PARAMETER Interval
        Analytics interval, e.g. 2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z

        .PARAMETER QueueIds
        Optional list of queueIds to restrict the query.

        .PARAMETER MediaType
        Optional media type filter (voice, chat, email, etc.)

        .PARAMETER TopN
        Number of "top" divisions to surface by abandon/error rate.

        .EXAMPLE
        Get-GCDivisionReport -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' -TopN 5
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
        [string[]]$QueueIds,

        [Parameter(Mandatory = $false)]
        [ValidateSet('voice','chat','email','callback','message')]
        [string]$MediaType,

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
        groupBy  = @('divisionId')
    }

    # Add optional filters
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

    if ($MediaType) {
        $baseBody.filter.predicates += @{
            dimension = 'mediaType'
            value     = $MediaType
        }
    }

    Write-Verbose "Requesting division aggregates for interval $Interval ..."
    $divisionAgg = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'POST' -Path '/api/v2/analytics/conversations/aggregates/query' -Body $baseBody

    $divisionRows = @()
    if ($divisionAgg.results) {
        foreach ($row in $divisionAgg.results) {
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

            $divisionId = $row.group.divisionId

            $divisionRows += [pscustomobject]@{
                DivisionId   = $divisionId
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

    # Rank top divisions by "badness" – high abandon, high error, etc.
    $divisionTop =
        $divisionRows |
        Sort-Object @{Expression = 'AbandonRate'; Descending = $true},
                    @{Expression = 'ErrorRate';   Descending = $true},
                    @{Expression = 'Offered';     Descending = $true} |
        Select-Object -First $TopN

    return [pscustomobject]@{
        Interval        = $Interval
        DivisionSummary = $divisionRows
        DivisionTop     = $divisionTop
    }
}
### END FILE: Public\Get-GCDivisionReport.ps1
