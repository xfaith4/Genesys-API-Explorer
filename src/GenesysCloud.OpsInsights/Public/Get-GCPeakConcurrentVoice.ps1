### BEGIN FILE: Public\Get-GCPeakConcurrentVoice.ps1
function Get-GCPeakConcurrentVoice {
    <#
        .SYNOPSIS
        Returns the peak concurrent voice call volume (1-minute granularity) for the specified interval.

        .DESCRIPTION
        - Submits an Analytics Conversation Detail Job filtered to voice media.
        - Streams job results and performs a sweep-line (delta) calculation to find the maximum number
          of simultaneous calls across all trunks/edges.
        - Returns a single statistic with the peak count and the minute where it first occurred.
        - Accepts pre-loaded conversation objects (e.g., fixtures) for offline validation/testing.

        .PARAMETER Interval
        Analytics interval for the job, e.g. 2025-12-01T00:00:00.000Z/2025-12-31T23:59:59.999Z.

        .PARAMETER BaseUri
        Region base URI, e.g. https://api.usw2.pure.cloud (resolved from Connect-GCCloud if omitted).

        .PARAMETER AccessToken
        OAuth bearer token (resolved from Connect-GCCloud if omitted).

        .PARAMETER PageSize
        Page size for job creation and results streaming. Defaults to 200.

        .PARAMETER PollSeconds
        Polling interval for job completion.

        .PARAMETER MaxPollMinutes
        Maximum time to wait for job completion before failing.

        .PARAMETER Conversations
        Optional array of conversation detail objects to compute the peak locally (skips API calls).

        .EXAMPLE
        Get-GCPeakConcurrentVoice -Interval '2025-11-01T00:00:00.000Z/2025-12-01T00:00:00.000Z'

        .EXAMPLE
        $fixture = Get-Content ./tests/fixtures/ConversationDetails.sample.json | ConvertFrom-Json
        Get-GCPeakConcurrentVoice -Interval '2024-02-01T00:00:00Z/2024-03-01T00:00:00Z' -Conversations $fixture.conversations
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BaseUri,

        [Parameter()]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$Interval,

        [Parameter()]
        [ValidateRange(1, 500)]
        [int]$PageSize = 200,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$PollSeconds = 5,

        [Parameter()]
        [ValidateRange(1, 240)]
        [int]$MaxPollMinutes = 60,

        [Parameter()]
        [object[]]$Conversations
    )

    $deltas = @{}
    $processed = 0

    $minuteFloor = {
        param([datetime]$Timestamp)
        return $Timestamp.AddSeconds(-$Timestamp.Second).AddMilliseconds(-$Timestamp.Millisecond)
    }

    $addDelta = {
        param([datetime]$Slot, [int]$Delta)
        if ($deltas.ContainsKey($Slot)) {
            $deltas[$Slot] = [int]$deltas[$Slot] + $Delta
        }
        else {
            $deltas[$Slot] = $Delta
        }
    }

    $processConversations = {
        param([object[]]$Batch)

        foreach ($conv in $Batch) {
            $start = if ($conv.conversationStart) { [datetime]$conv.conversationStart } else { $null }
            $end   = if ($conv.conversationEnd)   { [datetime]$conv.conversationEnd }   else { $null }

            if (-not $start -or -not $end) { continue }
            if ($end -le $start) { continue }

            $hasVoice = $false
            foreach ($participant in ($conv.participants | Where-Object { $_.sessions })) {
                foreach ($session in $participant.sessions) {
                    if ($session.mediaType -eq 'voice') {
                        $hasVoice = $true
                        break
                    }
                }
                if ($hasVoice) { break }
            }

            if (-not $hasVoice) { continue }

            $startSlot = & $minuteFloor $start.ToUniversalTime()
            $endSlot   = & $minuteFloor $end.ToUniversalTime()
            if ($end.ToUniversalTime() -gt $endSlot) {
                $endSlot = $endSlot.AddMinutes(1)
            }

            & $addDelta $startSlot 1
            & $addDelta $endSlot (-1)
            $processed++
        }
    }

    if (-not $Conversations) {
        $auth = Resolve-GCAuth -BaseUri $BaseUri -AccessToken $AccessToken
        $BaseUri = $auth.BaseUri
        $AccessToken = $auth.AccessToken

        $body = @{
            interval = $Interval
            order    = 'asc'
            orderBy  = 'conversationStart'
            paging   = @{
                pageSize   = $PageSize
                pageNumber = 1
            }
            segmentFilters = @(
                @{
                    type       = 'and'
                    predicates = @(
                        @{
                            type       = 'dimension'
                            dimension  = 'mediaType'
                            operator   = 'matches'
                            value      = 'voice'
                        }
                    )
                }
            )
        }

        $job = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'POST' -Path '/api/v2/analytics/conversations/details/jobs' -Body $body
        if (-not $job.id) {
            throw "Conversation detail job did not return an id. Raw: $($job | ConvertTo-Json -Depth 6)"
        }

        $deadline = (Get-Date).AddMinutes($MaxPollMinutes)
        do {
            $status = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'GET' -Path "/api/v2/analytics/conversations/details/jobs/$($job.id)"
            $state  = [string]$status.state
            Write-Verbose "Conversation detail job $($job.id) state: $state"

            if ($state -eq 'FULFILLED' -or $state -eq 'COMPLETED') { break }
            if ($state -eq 'FAILED') { throw "Conversation detail job $($job.id) failed." }
            if ((Get-Date) -gt $deadline) { throw "Conversation detail job $($job.id) did not complete in $MaxPollMinutes minute(s)." }
            Start-Sleep -Seconds $PollSeconds
        } while ($true)

        $cursor = $null
        while ($true) {
            $query = @{ pageSize = $PageSize }
            if ($cursor) { $query.cursor = $cursor }

            $result = Invoke-GCRequest -BaseUri $BaseUri -AccessToken $AccessToken -Method 'GET' -Path "/api/v2/analytics/conversations/details/jobs/$($job.id)/results" -Query $query
            $batch  = $result.conversations
            if (-not $batch -or -not $batch.Count) { break }

            & $processConversations $batch

            if ($result.cursor) {
                $cursor = $result.cursor
            }
            else {
                break
            }
        }
    }
    else {
        & $processConversations $Conversations
    }

    $current = 0
    $peak    = 0
    $peakSlots = New-Object System.Collections.Generic.List[datetime]

    foreach ($slot in ($deltas.Keys | Sort-Object { [datetime]$_ })) {
        $slotDt = [datetime]$slot
        $current += [int]$deltas[$slotDt]

        if ($current -gt $peak) {
            $peak = $current
            $peakSlots.Clear()
            [void]$peakSlots.Add($slotDt)
        }
        elseif ($current -eq $peak -and $peak -gt 0) {
            [void]$peakSlots.Add($slotDt)
        }
    }

    $result = [pscustomobject]@{
        Interval             = $Interval
        PeakConcurrentCalls  = $peak
        FirstPeakMinuteUtc   = if ($peakSlots.Count -gt 0) { $peakSlots[0] } else { $null }
        AllPeakMinutesUtc    = if ($peakSlots.Count -gt 0) { ($peakSlots | ForEach-Object { $_.ToString('yyyy-MM-dd HH:mm') }) -join '; ' } else { '' }
        ConversationsEvaluated = $processed
        Source               = if ($Conversations) { 'offline' } else { 'analytics:conversation-details-job' }
    }

    return $result
}
### END FILE
