### BEGIN FILE

<#
.SYNOPSIS
    Calculates peak concurrent voice calls per division for a monthly interval
    using Genesys Cloud Analytics Conversation Detail Jobs.

.DESCRIPTION
    - Authenticates to Genesys Cloud using OAuth Client Credentials.
    - Starts an async conversation detail job over the requested interval.
    - Filters to mediaType = voice.
    - Streams all job results via cursor-based paging.
    - Extracts conversationStart, conversationEnd, and divisionIds.
    - Converts timestamps to Eastern time (configurable).
    - Restricts analysis to Mon–Fri, 08:00–17:00 local time.
    - Computes per-division 1-minute concurrency and peak values.

    NOTE:
    - This relies on the Analytics Conversation Detail Job endpoint:
      POST /api/v2/analytics/conversations/details/jobs
      GET  /api/v2/analytics/conversations/details/jobs/{jobId}
      GET  /api/v2/analytics/conversations/details/jobs/{jobId}/results
    - You must grant the OAuth client appropriate analytics read scopes.

.PARAMETER ClientId
    OAuth client ID for Genesys Cloud (Client Credentials flow).

.PARAMETER ClientSecret
    OAuth client secret.

.PARAMETER Environment
    Genesys Cloud environment domain without the "api." prefix.
    Examples:
        - mypurecloud.com
        - usw2.pure.cloud
        - euw2.pure.cloud

.PARAMETER MonthStart
    Start of the reporting interval (local time). Will be converted to UTC.
    Default: first day of last full calendar month at 00:00.

.PARAMETER MonthEnd
    End of the reporting interval (local time, exclusive). Will be converted to UTC.
    Default: first day of current month at 00:00.

.PARAMETER TimeZoneId
    Windows time zone ID for local business hours logic.
    Default: 'Eastern Standard Time'.

.PARAMETER BusinessStartHourLocal
    Local hour (0–23) for business start. Default: 8.

.PARAMETER BusinessEndHourLocal
    Local hour (0–23) for business end. Default: 17.

.PARAMETER OutputCsvPath
    Path for CSV output summarising peak concurrency per division.

.PARAMETER IncludeDivisionLookup
    If $true, attempts to fetch division names via
      GET /api/v2/authorization/divisions
    and include them in the output.

.EXAMPLE
    .\Get-GCPeakConcurrentByDivision.ps1 `
        -ClientId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' `
        -ClientSecret 'super-secret' `
        -Environment 'usw2.pure.cloud' `
        -OutputCsvPath '.\PeakConcurrencyByDivision.csv'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [string]$Environment,

    [datetime]$MonthStart,
    [datetime]$MonthEnd,

    [string]$TimeZoneId = 'Eastern Standard Time',

    [int]$BusinessStartHourLocal = 8,
    [int]$BusinessEndHourLocal   = 17,

    [string]$OutputCsvPath = '.\PeakConcurrentByDivision.csv',

    [bool]$IncludeDivisionLookup = $true
)

# -----------------------------
# Basic TLS hygiene for PS 5.1
# -----------------------------
# Ensure we can talk TLS 1.2+ or APIs will just sulk.
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.SecurityProtocolType]::Tls12 -bor `
    [Net.SecurityProtocolType]::Tls13

# -----------------------------
# Default interval if not set
# -----------------------------
if (-not $MonthEnd) {
    # First day of current month (local)
    $now        = Get-Date
    $MonthEnd   = Get-Date -Year $now.Year -Month $now.Month -Day 1 `
                           -Hour 0 -Minute 0 -Second 0 -Millisecond 0
}

if (-not $MonthStart) {
    # First day of previous month (local)
    $prevMonth = $MonthEnd.AddMonths(-1)
    $MonthStart = Get-Date -Year $prevMonth.Year -Month $prevMonth.Month -Day 1 `
                            -Hour 0 -Minute 0 -Second 0 -Millisecond 0
}

if ($MonthEnd -le $MonthStart) {
    throw "MonthEnd must be greater than MonthStart. Got $($MonthStart) to $($MonthEnd)."
}

Write-Verbose "Reporting window (local): $($MonthStart) -> $($MonthEnd)"

# -----------------------------
# Shared script-scope state
# -----------------------------
# Script-scoped token cache so repeated calls don't re-auth unless expired.
$script:GcAccessToken      = $null
$script:GcTokenExpiryUtc   = Get-Date 0

# Build base API URI from environment.
# Example: usw2.pure.cloud -> https://api.usw2.pure.cloud
$script:GcBaseUri = "https://api.$Environment".TrimEnd('/')

# -----------------------------
# Helper: Get OAuth token
# -----------------------------
function Get-GCAccessToken {
    <#
        Gets (and caches) an OAuth access token via Client Credentials.
    #>
    if ($script:GcAccessToken -and (Get-Date) -lt $script:GcTokenExpiryUtc) {
        return $script:GcAccessToken
    }

    $tokenUri = "$($script:GcBaseUri)/oauth/token"

    # Prepare basic auth header: base64("clientId:clientSecret")
    $pairBytes   = [System.Text.Encoding]::UTF8.GetBytes("$ClientId`:$ClientSecret")
    $basicToken  = [Convert]::ToBase64String($pairBytes)

    $headers = @{
        Authorization = "Basic $basicToken"
    }

    $body = @{
        grant_type = 'client_credentials'
    }

    Write-Verbose "Requesting new Genesys Cloud OAuth token from $($tokenUri)..."

    try {
        $response = Invoke-RestMethod -Method Post -Uri $tokenUri `
                                      -Headers $headers -Body $body
    }
    catch {
        throw "OAuth token request failed against $($tokenUri): $($_)"
    }

    if (-not $response.access_token) {
        throw "OAuth token response did not contain access_token. Raw: $($response | ConvertTo-Json -Depth 5)"
    }

    $script:GcAccessToken = $response.access_token

    # expires_in is seconds from now.
    $expiresInSeconds     = [int]($response.expires_in)
    # Renew a minute early just to be safe.
    $script:GcTokenExpiryUtc = (Get-Date).ToUniversalTime().AddSeconds($expiresInSeconds - 60)

    return $script:GcAccessToken
}

# -----------------------------
# Helper: Invoke GC REST call
# -----------------------------
function Invoke-GCRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,   # Path after base Uri (starts with /)
        [object]$Body,
        [hashtable]$Query
    )

    # Build full URL
    $uriBuilder = [System.UriBuilder]::new($script:GcBaseUri)
    $uriBuilder.Path = $Path.TrimStart('/')

    if ($Query) {
        # Simple query string builder, no fancy encoding beyond key=value pairs.
        $pairs = @()
        foreach ($k in $Query.Keys) {
            $v = $Query[$k]
            if ($null -ne $v -and $v -ne '') {
                $pairs += ("{0}={1}" -f [uri]::EscapeDataString($k), [uri]::EscapeDataString([string]$v))
            }
        }
        $uriBuilder.Query = ($pairs -join '&')
    }

    $uri     = $uriBuilder.Uri.AbsoluteUri
    $token   = Get-GCAccessToken

    $headers = @{
        Authorization = "Bearer $token"
        'Content-Type' = 'application/json'
    }

    $invokeParams = @{
        Method  = $Method
        Uri     = $uri
        Headers = $headers
    }

    if ($null -ne $Body) {
        $invokeParams.Body = ($Body | ConvertTo-Json -Depth 10)
    }

    Write-Verbose "Calling $($Method) $($uri)"

    try {
        $result = Invoke-RestMethod @invokeParams
        return $result
    }
    catch {
        throw "API call failed: $($Method) $($uri) :: $($_)"
    }
}

# -----------------------------
# Helper: Start details job
# -----------------------------
function Start-GCConversationDetailsJob {
    param(
        [Parameter(Mandatory = $true)][datetime]$StartUtc,
        [Parameter(Mandatory = $true)][datetime]$EndUtc
    )

    # Interval string in ISO 8601 UTC
    $interval = "{0}/{1}" -f $StartUtc.ToString('o'), $EndUtc.ToString('o')

    # Body roughly follows Conversation Detail Query model:
    # - Filter to voice mediaType via segmentFilters
    # - Order by conversationStart ascending
    $body = @{
        interval        = $interval
        order           = 'asc'
        orderBy         = 'conversationStart'
        paging          = @{
            pageSize   = 100
            pageNumber = 1
        }
        segmentFilters  = @(
            @{
                type       = 'and'
                predicates = @(
                    @{
                        type      = 'dimension'
                        dimension = 'mediaType'
                        operator  = 'matches'
                        value     = 'voice'
                    }
                )
            }
        )
    }

    $response = Invoke-GCRequest -Method 'POST' `
                                 -Path '/api/v2/analytics/conversations/details/jobs' `
                                 -Body $body

    if (-not $response.id) {
        throw "Conversation details job did not return an id. Raw: $($response | ConvertTo-Json -Depth 6)"
    }

    Write-Host "Started conversation detail job $($response.id) with interval $($interval)" -ForegroundColor Cyan
    return $response.id
}

# -----------------------------
# Helper: Wait for job completion
# -----------------------------
function Wait-GCConversationDetailsJob {
    param(
        [Parameter(Mandatory = $true)][string]$JobId,
        [int]$PollSeconds = 10,
        [int]$MaxMinutes  = 60
    )

    $deadline = (Get-Date).AddMinutes($MaxMinutes)

    while ($true) {
        $job = Invoke-GCRequest -Method 'GET' `
                                -Path "/api/v2/analytics/conversations/details/jobs/$JobId"

        $state = [string]$job.state
        Write-Host "Job $($JobId) state: $($state)" -ForegroundColor Yellow

        switch -Regex ($state) {
            '^FULFILLED$' { return $job }
            '^COMPLETED$' { return $job } # In case older docs use COMPLETED
            '^FAILED$'    { throw "Conversation details job $($JobId) FAILED. Raw: $($job | ConvertTo-Json -Depth 6)" }
            default       { }
        }

        if ((Get-Date) -gt $deadline) {
            throw "Conversation details job $($JobId) did not complete within $($MaxMinutes) minutes. Last state: $($state)"
        }

        Start-Sleep -Seconds $PollSeconds
    }
}

# -----------------------------
# Helper: Stream job results (cursor)
# -----------------------------
function Get-GCConversationDetailsResults {
    param(
        [Parameter(Mandatory = $true)][string]$JobId,
        [int]$PageSize = 100
    )

    # This is implemented as a PowerShell "generator" via Write-Output
    # so we don't have to hold all conversations in memory at once.

    $cursor       = $null
    $pageCounter  = 0

    while ($true) {
        $query = @{
            pageSize = $PageSize
        }

        if ($cursor) {
            $query.cursor = $cursor
        }

        $response = Invoke-GCRequest -Method 'GET' `
                                     -Path "/api/v2/analytics/conversations/details/jobs/$JobId/results" `
                                     -Query $query

        $pageCounter++

        $conversations = $response.conversations
        if (-not $conversations -or -not $conversations.Count) {
            Write-Host "No more conversations returned after $($pageCounter) page(s)." -ForegroundColor Green
            break
        }

        Write-Host "Fetched page $($pageCounter) with $($conversations.Count) conversation(s)." -ForegroundColor Green

        # Yield each conversation object
        foreach ($c in $conversations) {
            Write-Output $c
        }

        # Some implementations use "cursor" in the response to continue.
        # If no cursor returned, we assume this was the last page.
        if ($response.cursor) {
            $cursor = $response.cursor
        }
        else {
            break
        }
    }
}

# -----------------------------
# Helper: Get division lookup
# -----------------------------
function Get-GCDivisionLookup {
    if (-not $IncludeDivisionLookup) {
        return @{}
    }

    Write-Host "Fetching authorization divisions for name lookup..." -ForegroundColor Cyan

    $pageNumber = 1
    $pageSize   = 100
    $lookup     = @{}

    while ($true) {
        $query = @{
            pageNumber = $pageNumber
            pageSize   = $pageSize
        }

        $resp = Invoke-GCRequest -Method 'GET' `
                                 -Path '/api/v2/authorization/divisions' `
                                 -Query $query

        $entities = $resp.entities
        if (-not $entities -or -not $entities.Count) {
            break
        }

        foreach ($d in $entities) {
            if ($d.id) {
                $lookup[$d.id] = $d.name
            }
        }

        if ($pageNumber -ge [int]$resp.pageCount) {
            break
        }

        $pageNumber++
    }

    Write-Host "Loaded $($lookup.Keys.Count) division(s) into lookup cache." -ForegroundColor Green
    return $lookup
}

# -----------------------------
# Helper: Floor to minute
# -----------------------------
function Get-MinuteFloor {
    param(
        [Parameter(Mandatory = $true)][datetime]$Timestamp
    )

    # Drops seconds and milliseconds.
    return $Timestamp.AddSeconds(-$Timestamp.Second).AddMilliseconds(-$Timestamp.Millisecond)
}

# -----------------------------
# Main: Compute concurrency
# -----------------------------
function Get-GCPeakConcurrentByDivision {
    [CmdletBinding()]
    param()

    # Resolve time zone
    try {
        $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId)
    }
    catch {
        throw "Time zone '$($TimeZoneId)' is not valid on this host. Check Windows time zone IDs."
    }

    # Convert reporting window boundaries to UTC for Analytics job
    $startUtc = [System.TimeZoneInfo]::ConvertTimeToUtc($MonthStart, $tz)
    $endUtc   = [System.TimeZoneInfo]::ConvertTimeToUtc($MonthEnd,   $tz)

    Write-Host "Analytics job interval (UTC): $($startUtc.ToString('o')) / $($endUtc.ToString('o'))" -ForegroundColor Cyan

    # Start job
    $jobId = Start-GCConversationDetailsJob -StartUtc $startUtc -EndUtc $endUtc

    # Wait for completion
    [void](Wait-GCConversationDetailsJob -JobId $jobId)

    # Division lookup (optional)
    $divisionLookup = Get-GCDivisionLookup

    # Dictionary: divisionId -> hashtable of minuteSlot -> delta count
    $divisionDeltas = @{}

    $businessStartSpan = [TimeSpan]::FromHours($BusinessStartHourLocal)
    $businessEndSpan   = [TimeSpan]::FromHours($BusinessEndHourLocal)

    # Stream all conversations
    $convCount = 0

    Get-GCConversationDetailsResults -JobId $jobId | ForEach-Object {
        $conv = $_
        $convCount++

        # Extract conversation-level fields; adjust if your org uses a different shape.
        $convId          = $conv.conversationId
        $conversationStartUtc = $conv.conversationStart
        $conversationEndUtc   = $conv.conversationEnd

        if (-not $conversationStartUtc -or -not $conversationEndUtc) {
            # Skip incomplete / in-flight calls for this historical report.
            # You can choose to treat null End as MonthEnd for near-real-time analysis.
            return
        }

        $divisionIds = $conv.divisionIds
        if (-not $divisionIds -or -not $divisionIds.Count) {
            # If no division, bucket under 'UNKNOWN'.
            $divisionIds = @('UNKNOWN')
        }

        # Convert start/end to local time
        $startLocal = [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$conversationStartUtc, $tz)
        $endLocal   = [System.TimeZoneInfo]::ConvertTimeFromUtc([datetime]$conversationEndUtc,   $tz)

        # Simple guard: ignore conversations entirely outside we care about.
        if ($endLocal -le $MonthStart -or $startLocal -ge $MonthEnd) {
            return
        }

        # NOTE: This script assumes calls do not span multiple calendar days.
        # If they do, you'll need to split the call into per-day segments.
        if ($startLocal.Date -ne $endLocal.Date) {
            # Clamp to the start date, still better than silently double-counting.
            $endLocal = $startLocal.Date.Add($businessEndSpan)
        }

        # Skip weekends
        if ($startLocal.DayOfWeek -eq [System.DayOfWeek]::Saturday -or
            $startLocal.DayOfWeek -eq [System.DayOfWeek]::Sunday) {
            return
        }

        # Business-hours window for that day
        $businessDayStart = $startLocal.Date.Add($businessStartSpan)
        $businessDayEnd   = $startLocal.Date.Add($businessEndSpan)

        # Clip to business hours
        $effectiveStart = if ($startLocal -lt $businessDayStart) { $businessDayStart } else { $startLocal }
        $effectiveEnd   = if ($endLocal   -gt $businessDayEnd)   { $businessDayEnd   } else { $endLocal }

        if ($effectiveEnd -le $effectiveStart) {
            # After clipping, nothing remains inside the window.
            return
        }

        # Floor to minute for start; derive exclusive end minute.
        $startSlot = Get-MinuteFloor -Timestamp $effectiveStart
        $endSlot   = Get-MinuteFloor -Timestamp $effectiveEnd

        # If end has any seconds > 0, bump to the next minute so the last partial minute counts.
        if ($effectiveEnd -gt $endSlot) {
            $endSlot = $endSlot.AddMinutes(1)
        }

        foreach ($divId in $divisionIds) {
            if (-not $divisionDeltas.ContainsKey($divId)) {
                $divisionDeltas[$divId] = @{}
            }

            $deltaMap = $divisionDeltas[$divId]

            # +1 at call start
            if ($deltaMap.ContainsKey($startSlot)) {
                $deltaMap[$startSlot] = [int]$deltaMap[$startSlot] + 1
            }
            else {
                $deltaMap[$startSlot] = 1
            }

            # -1 at end (exclusive)
            if ($deltaMap.ContainsKey($endSlot)) {
                $deltaMap[$endSlot] = [int]$deltaMap[$endSlot] - 1
            }
            else {
                $deltaMap[$endSlot] = -1
            }
        }
    }

    Write-Host "Processed $($convCount) conversation(s) into concurrency deltas." -ForegroundColor Cyan

    # Now compute per-division running sums and peaks
    $results = @()

    foreach ($divId in $divisionDeltas.Keys) {
        $deltaMap = $divisionDeltas[$divId]

        # Sort slots by actual DateTime (cast keys if they came back as strings)
        $sortedSlots = $deltaMap.Keys | Sort-Object { [datetime]$_ }

        $current   = 0
        $peak      = 0
        $peakSlots = New-Object System.Collections.Generic.List[datetime]

        foreach ($slot in $sortedSlots) {
            $slotDt   = [datetime]$slot
            $current += [int]$deltaMap[$slotDt]

            if ($current -gt $peak) {
                $peak = $current
                $peakSlots.Clear()
                [void]$peakSlots.Add($slotDt)
            }
            elseif ($current -eq $peak -and $peak -gt 0) {
                [void]$peakSlots.Add($slotDt)
            }
        }

        $divisionName = $null
        if ($IncludeDivisionLookup -and $divisionLookup.ContainsKey($divId)) {
            $divisionName = $divisionLookup[$divId]
        }

        $firstPeak = if ($peakSlots.Count -gt 0) { $peakSlots[0] } else { $null }
        $allPeaks  = if ($peakSlots.Count -gt 0) {
            ($peakSlots | ForEach-Object { $_.ToString('yyyy-MM-dd HH:mm') }) -join '; '
        }
        else {
            ''
        }

        $results += [pscustomobject]@{
            DivisionId            = $divId
            DivisionName          = $divisionName
            PeakConcurrentCalls   = $peak
            FirstPeakMinuteLocal  = $firstPeak
            AllPeakMinutesLocal   = $allPeaks
        }
    }

    # Write CSV summary
    $results | Sort-Object PeakConcurrentCalls -Descending | Export-Csv -Path $OutputCsvPath -NoTypeInformation

    Write-Host "Peak concurrency summary written to $($OutputCsvPath)" -ForegroundColor Green

    # Return objects to the pipeline for interactive inspection as well
    return ($results | Sort-Object PeakConcurrentCalls -Descending)
}

# -----------------------------
# Entry point (when run directly)
# -----------------------------
# If you dot-source the script, nothing runs automatically.
if ($MyInvocation.InvocationName -ne '.') {
    Get-GCPeakConcurrentByDivision
}

### END FILE
