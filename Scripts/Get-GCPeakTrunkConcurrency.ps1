### BEGIN FILE: Get-GCPeakTrunkConcurrency.ps1
<#
.SYNOPSIS
  Peak Concurrent "Trunk-Active" Voice Calls (per minute) for a month from Genesys Cloud Conversation Details Jobs.

.DESCRIPTION
  - Uses /api/v2/analytics/conversations/details/jobs (async)
  - Pages results via cursor until cursor is absent (jobs paging behavior)
  - Extracts intervals from VOICE sessions where:
      * ani starts with tel:
      * dnis starts with tel:
      * participant appears external/customer (guard to avoid counting agent legs)
    Then excludes segmentType=wrapup and builds an active interval from remaining segments.
  - Computes peak concurrency using a minute delta sweep (fast, deterministic).
  - Includes rate-limit aware request wrapper (handles 429 + sleeps until reset).

.REQUIREMENTS
  - PowerShell 5.1 or 7+
  - OAuth client credentials with permission to run analytics conversation details jobs.
#>

[CmdletBinding()]
param(
    # Genesys Cloud environment suffix, e.g. "mypurecloud.com" or "usw2.pure.cloud"
    [Parameter(Mandatory)]
    [string]$Environment,

    # OAuth Client Id
    [Parameter(Mandatory)]
    [string]$ClientId,

    # OAuth Client Secret (SecureString strongly preferred)
    [Parameter(Mandatory)]
    [securestring]$ClientSecret,

    # Target month (YYYY-MM). Example: "2025-11"
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{4}-\d{2}$')]
    [string]$YearMonth,

    # Chunk size (days) for job intervals (7 is usually a good balance)
    [ValidateRange(1,31)]
    [int]$ChunkDays = 7,

    # Results page size (Genesys supports pageSize in results call; keep reasonable)
    [ValidateRange(25,500)]
    [int]$PageSize = 200,

    # Poll frequency while waiting for async job fulfillment
    [ValidateRange(2,60)]
    [int]$PollSeconds = 5,

    # Output folder (created if missing)
    [string]$OutputDir = "",

    # If set, uses ONLY tel/tel filtering (no participant guard). Not recommended.
    [switch]$LooseTelOnly
)

# -----------------------------
# Helpers: time + output folder
# -----------------------------
function New-OutputFolder {
    param([string]$Base)
    if ([string]::IsNullOrWhiteSpace($Base)) {
        $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $Base = ".\GC_PeakTrunk_$($YearMonth.Replace('-',''))_$stamp"
    }
    if (-not (Test-Path -LiteralPath $Base)) {
        New-Item -ItemType Directory -Path $Base | Out-Null
    }
    return (Resolve-Path -LiteralPath $Base).Path
}

function ConvertTo-UtcIsoZ {
    param([datetime]$Dt)
    $u = $Dt.ToUniversalTime()
    return $u.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

function Get-MonthIntervalUtc {
    param([string]$Ym)

    $y = [int]$Ym.Substring(0,4)
    $m = [int]$Ym.Substring(5,2)

    $start = [datetime]::SpecifyKind((Get-Date -Year $y -Month $m -Day 1 -Hour 0 -Minute 0 -Second 0), [DateTimeKind]::Local).ToUniversalTime()
    $end   = $start.AddMonths(1)

    # Return as [datetime] in UTC kind (safe for formatting)
    return [pscustomobject]@{
        StartUtc = [datetime]::SpecifyKind($start, [DateTimeKind]::Utc)
        EndUtc   = [datetime]::SpecifyKind($end,   [DateTimeKind]::Utc)
    }
}

# ---------------------------------------
# OAuth: Client Credentials access token
# ---------------------------------------
function ConvertFrom-SecureStringPlain {
    param([Parameter(Mandatory)][securestring]$Secure)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Get-GCAccessToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Env,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][securestring]$Secret
    )

    $secretPlain = ConvertFrom-SecureStringPlain -Secure $Secret
    try {
        $pair  = "{0}:{1}" -f $Id, $secretPlain
        $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

        $uri = "https://login.$($Env)/oauth/token"
        $headers = @{ Authorization = "Basic $basic" }
        $body = "grant_type=client_credentials"

        Write-Host "Auth: requesting client-credentials token from $($uri) ..." -ForegroundColor Cyan

        $resp = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $uri -Headers $headers `
            -ContentType 'application/x-www-form-urlencoded' -Body $body

        $json = $resp.Content | ConvertFrom-Json
        if (-not $json.access_token) { throw "Token response missing access_token." }

        return $json.access_token
    }
    finally {
        # Best-effort: wipe plaintext variable reference
        $secretPlain = $null
    }
}

# ---------------------------------------
# Rate-limit aware HTTP wrapper
# ---------------------------------------
function Get-RateLimitSnapshot {
    param([hashtable]$Headers)

    # Genesys historically uses inin-ratelimit-* (allowed/count/reset). :contentReference[oaicite:3]{index=3}
    # Some infrastructure uses x-ratelimit-* or other variants; we handle both.
    $limit = $null
    $used  = $null
    $remain = $null
    $reset = $null

    # Normalize keys (case-insensitive)
    $keys = @{}
    foreach ($k in $Headers.Keys) { $keys[$k.ToLowerInvariant()] = $k }

    function Get-H([string]$name) {
        $lk = $name.ToLowerInvariant()
        if ($keys.ContainsKey($lk)) { return [string]$Headers[$keys[$lk]] }
        return $null
    }

    $ininAllowed = Get-H 'inin-ratelimit-allowed'
    $ininCount   = Get-H 'inin-ratelimit-count'
    $ininReset   = Get-H 'inin-ratelimit-reset'
    $ininRemain  = Get-H 'inin-ratelimit-remaining'

    $xLimit      = Get-H 'x-ratelimit-limit'
    $xRemain     = Get-H 'x-ratelimit-remaining'
    $xReset      = Get-H 'x-ratelimit-reset'

    if ($ininAllowed) { $limit = [int]$ininAllowed }
    if ($ininCount)   { $used  = [int]$ininCount }
    if ($ininRemain)  { $remain = [int]$ininRemain }
    if ($ininReset)   { $reset = $ininReset }

    if (-not $limit -and $xLimit)  { $limit = [int]$xLimit }
    if (-not $remain -and $xRemain){ $remain = [int]$xRemain }
    if (-not $reset -and $xReset)  { $reset = $xReset }

    # Derive remaining from limit-used if needed
    if (-not $remain -and $limit -and ($used -ne $null)) {
        $remain = [Math]::Max(0, ($limit - $used))
    }

    # Reset parsing:
    # - Could be epoch seconds
    # - Could be seconds-until-reset
    # We'll heuristically interpret.
    $resetSeconds = $null
    if ($reset) {
        if ($reset -match '^\d+$') {
            $n = [int64]$reset
            $nowEpoch = [int64][Math]::Floor(([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()))
            if ($n -gt ($nowEpoch + 120)) {
                # Looks like epoch seconds
                $resetSeconds = [Math]::Max(0, ($n - $nowEpoch))
            }
            else {
                # Looks like seconds until reset
                $resetSeconds = [Math]::Max(0, [int]$n)
            }
        }
    }

    return [pscustomobject]@{
        Limit        = $limit
        Used         = $used
        Remaining    = $remain
        ResetSeconds = $resetSeconds
    }
}

function Invoke-GCRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$AccessToken,
        [object]$Body = $null,
        [hashtable]$ExtraHeaders = $null,
        [int]$MaxRetries = 6
    )

    $attempt = 0
    while ($true) {
        $attempt++

        $headers = @{
            Authorization = "Bearer $AccessToken"
            Accept        = "application/json"
        }
        if ($ExtraHeaders) {
            foreach ($k in $ExtraHeaders.Keys) { $headers[$k] = $ExtraHeaders[$k] }
        }

        $respHeaders = $null

        try {
            if ($Body -ne $null) {
                $payload = ($Body | ConvertTo-Json -Depth 50)
                $resp = Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $Uri -Headers $headers `
                    -ContentType 'application/json' -Body $payload -ResponseHeadersVariable respHeaders
            }
            else {
                $resp = Invoke-WebRequest -UseBasicParsing -Method $Method -Uri $Uri -Headers $headers `
                    -ResponseHeadersVariable respHeaders
            }

            $rl = Get-RateLimitSnapshot -Headers $respHeaders
            if ($rl.Limit) {
                $msg = "RateLimit: remaining=$($rl.Remaining) limit=$($rl.Limit)"
                if ($rl.ResetSeconds -ne $null) { $msg += " resetSec=$($rl.ResetSeconds)" }
                Write-Host $msg -ForegroundColor DarkGray
            }

            if ($resp.Content -and $resp.Content.Trim().StartsWith('{')) {
                return ($resp.Content | ConvertFrom-Json)
            }
            elseif ($resp.Content -and $resp.Content.Trim().StartsWith('[')) {
                return ($resp.Content | ConvertFrom-Json)
            }
            else {
                return $resp.Content
            }
        }
        catch {
            $ex = $_.Exception
            $statusCode = $null
            $retryAfterSec = $null
            $headersFromError = $null
            $bodyText = $null

            if ($ex.Response) {
                try {
                    $statusCode = [int]$ex.Response.StatusCode
                } catch { }

                try {
                    $headersFromError = @{}
                    foreach ($k in $ex.Response.Headers.Keys) { $headersFromError[$k] = $ex.Response.Headers[$k] }
                } catch { }

                try {
                    $stream = $ex.Response.GetResponseStream()
                    if ($stream) {
                        $reader = New-Object System.IO.StreamReader($stream)
                        $bodyText = $reader.ReadToEnd()
                        $reader.Close()
                    }
                } catch { }

                if ($headersFromError) {
                    # Retry-After is the simplest
                    $ra = $headersFromError['Retry-After']
                    if ($ra -and ($ra -match '^\d+$')) { $retryAfterSec = [int]$ra }
                }
            }

            # Rate limited
            if ($statusCode -eq 429) {
                $wait = $retryAfterSec

                if (-not $wait -and $headersFromError) {
                    $rl = Get-RateLimitSnapshot -Headers $headersFromError
                    if ($rl.ResetSeconds -ne $null) { $wait = [Math]::Max(1, $rl.ResetSeconds) }
                }

                if (-not $wait) { $wait = 10 }

                Write-Host "HTTP 429 rate-limited. Sleeping $($wait)s then retrying ($attempt/$MaxRetries)..." -ForegroundColor Yellow
                Start-Sleep -Seconds $wait
            }
            # Transient gateway-ish failures
            elseif ($statusCode -in 502,503,504) {
                if ($attempt -ge $MaxRetries) { throw }
                $backoff = [Math]::Min(60, [Math]::Pow(2, $attempt))
                Write-Host "HTTP $($statusCode) transient error. Sleeping $($backoff)s then retrying ($attempt/$MaxRetries)..." -ForegroundColor Yellow
                Start-Sleep -Seconds $backoff
            }
            else {
                $msg = "Request failed: $($Method) $($Uri)"
                if ($statusCode) { $msg += " status=$($statusCode)" }
                if ($bodyText)   { $msg += "`nBody: $bodyText" }
                throw $msg
            }

            if ($attempt -ge $MaxRetries) {
                throw "Max retries reached for $($Method) $($Uri)"
            }
        }
    }
}

# ---------------------------------------
# Genesys Conversation Details Jobs
# ---------------------------------------
function New-GCConversationDetailsJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ApiBase,
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][string]$IntervalIso
    )

    $uri = "$($ApiBase)/api/v2/analytics/conversations/details/jobs"

    # Best-effort server-side filter to VOICE media. If your org rejects segmentFilters for jobs,
    # we'll automatically fall back to "interval only".
    $bodyPreferred = @{
        interval = $IntervalIso
        order    = "asc"
        orderBy  = "conversationStart"
        segmentFilters = @(
            @{
                type = "and"
                predicates = @(
                    @{
                        type      = "dimension"
                        dimension = "mediaType"
                        operator  = "matches"
                        value     = "voice"
                    }
                )
            }
        )
    }

    try {
        Write-Host "Job: creating details job for interval $($IntervalIso) ..." -ForegroundColor Cyan
        return (Invoke-GCRequest -Method Post -Uri $uri -AccessToken $AccessToken -Body $bodyPreferred)
    }
    catch {
        Write-Host "Job: server-side filter rejected; retrying with minimal body (interval only)..." -ForegroundColor Yellow
        $bodyFallback = @{ interval = $IntervalIso }
        return (Invoke-GCRequest -Method Post -Uri $uri -AccessToken $AccessToken -Body $bodyFallback)
    }
}

function Get-GCConversationDetailsJobStatus {
    param(
        [Parameter(Mandatory)][string]$ApiBase,
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][string]$JobId
    )
    $uri = "$($ApiBase)/api/v2/analytics/conversations/details/jobs/$($JobId)"
    return (Invoke-GCRequest -Method Get -Uri $uri -AccessToken $AccessToken)
}

function Get-GCConversationDetailsJobResultsAll {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ApiBase,
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][string]$JobId,
        [Parameter(Mandatory)][int]$PageSize
    )

    $all = New-Object System.Collections.Generic.List[object]
    $cursor = $null
    $page = 0

    while ($true) {
        $page++
        $q = "pageSize=$($PageSize)"
        if ($cursor) { $q += "&cursor=$([uri]::EscapeDataString($cursor))" }

        $uri = "$($ApiBase)/api/v2/analytics/conversations/details/jobs/$($JobId)/results?$q"

        Write-Host "Job $($JobId): fetching results page $($page) ..." -ForegroundColor DarkCyan
        $resp = Invoke-GCRequest -Method Get -Uri $uri -AccessToken $AccessToken

        # Response shape can vary by SDK/version; handle common patterns.
        $rows = $null
        if ($resp.PSObject.Properties.Name -contains 'conversations') { $rows = @($resp.conversations) }
        elseif ($resp.PSObject.Properties.Name -contains 'results')   { $rows = @($resp.results) }
        else { $rows = @() }

        foreach ($r in $rows) { $all.Add($r) }

        # Cursor: jobs end when cursor is absent (forum confirmed behavior). :contentReference[oaicite:4]{index=4}
        $next = $null
        if ($resp.PSObject.Properties.Name -contains 'cursor') { $next = [string]$resp.cursor }

        if ([string]::IsNullOrWhiteSpace($next)) { break }
        $cursor = $next
    }

    return $all
}

# ---------------------------------------
# Trunk interval extraction (wrapup excluded)
# ---------------------------------------
function Get-SegmentTimes {
    param([object]$Seg)

    # Support both naming styles if they show up
    $s = $null
    $e = $null

    if ($Seg.PSObject.Properties.Name -contains 'segmentStart') { $s = $Seg.segmentStart }
    elseif ($Seg.PSObject.Properties.Name -contains 'startTime') { $s = $Seg.startTime }

    if ($Seg.PSObject.Properties.Name -contains 'segmentEnd') { $e = $Seg.segmentEnd }
    elseif ($Seg.PSObject.Properties.Name -contains 'endTime') { $e = $Seg.endTime }

    if (-not $s -or -not $e) { return $null }

    return [pscustomobject]@{
        StartUtc = [datetime]$s
        EndUtc   = [datetime]$e
    }
}

function Extract-TrunkIntervals {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$ConversationRecord,
        [switch]$LooseTelOnly
    )

    $out = New-Object System.Collections.Generic.List[object]

    foreach ($p in @($ConversationRecord.participants)) {

        $purpose = [string]$p.purpose
        $ptype   = if ($p.PSObject.Properties.Name -contains 'participantType') { [string]$p.participantType } else { "" }

        $looksExternal =
            ($purpose -match '(?i)\bcustomer\b|\bexternal\b') -or
            ($ptype   -match '(?i)\bexternal\b')

        foreach ($s in @($p.sessions)) {

            if ($s.mediaType -ne 'voice') { continue }

            $ani  = [string]$s.ani
            $dnis = [string]$s.dnis

            if ($ani  -notmatch '(?i)^tel:' ) { continue }
            if ($dnis -notmatch '(?i)^tel:' ) { continue }

            # Guard: avoid counting agent legs that also happen to show tel: ani/dnis.
            if (-not $LooseTelOnly) {
                if (-not $looksExternal) { continue }
            }

            # Extra defensive guard: if sessionDnis exists and is sip:, it's likely internal.
            if ($s.PSObject.Properties.Name -contains 'sessionDnis') {
                $sd = [string]$s.sessionDnis
                if ($sd -match '(?i)^sip:') { continue }
            }

            # Build interval from non-wrapup segments (wrapup excluded)
            $segs = @($s.segments) | Where-Object {
                $_ -and ([string]$_.segmentType -notmatch '(?i)^wrapup$')
            } | ForEach-Object {
                $t = Get-SegmentTimes -Seg $_
                if ($t) {
                    [pscustomobject]@{
                        SegmentType = [string]$_.segmentType
                        StartUtc    = $t.StartUtc
                        EndUtc      = $t.EndUtc
                    }
                }
            } | Where-Object { $_ } | Sort-Object StartUtc

            if (-not $segs -or $segs.Count -lt 1) { continue }

            $startUtc = [datetime]$segs[0].StartUtc
            $endUtc   = [datetime]($segs | Select-Object -Last 1).EndUtc
            if ($endUtc -le $startUtc) { continue }

            $divs = @()
            if ($ConversationRecord.PSObject.Properties.Name -contains 'divisionIds') {
                $divs = @($ConversationRecord.divisionIds)
            }

            $out.Add([pscustomobject]@{
                ConversationId = $ConversationRecord.conversationId
                ParticipantId  = $p.participantId
                Purpose        = $purpose
                SessionId      = $s.sessionId
                Ani            = $ani
                Dnis           = $dnis
                DivisionIds    = ($divs -join ';')
                StartUtc       = $startUtc
                EndUtc         = $endUtc
            })
        }
    }

    return $out
}

# ---------------------------------------
# Peak concurrency (minute delta sweep)
# ---------------------------------------
function Get-PeakConcurrentMinuteSeries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Intervals,
        [Parameter(Mandatory)][datetime]$MonthStartUtc,
        [Parameter(Mandatory)][datetime]$MonthEndUtc
    )

    $delta = @{}

    foreach ($x in $Intervals) {
        $s = [datetime]$x.StartUtc
        $e = [datetime]$x.EndUtc
        if ($e -le $s) { continue }

        # Clamp to month window so boundaries don't drift
        if ($s -lt $MonthStartUtc) { $s = $MonthStartUtc }
        if ($e -gt $MonthEndUtc)   { $e = $MonthEndUtc }
        if ($e -le $s) { continue }

        # Floor start to minute
        $startMin = Get-Date $s -Second 0 -Millisecond 0

        # Ceil end to minute
        $endMin = Get-Date $e -Second 0 -Millisecond 0
        if ($e.Second -ne 0 -or $e.Millisecond -ne 0) {
            $endMin = $endMin.AddMinutes(1)
        }

        if (-not $delta.ContainsKey($startMin)) { $delta[$startMin] = 0 }
        if (-not $delta.ContainsKey($endMin))   { $delta[$endMin]   = 0 }

        $delta[$startMin] += 1
        $delta[$endMin]   -= 1
    }

    # Build full minute series for the month (43k-ish rows; totally manageable)
    $series = New-Object System.Collections.Generic.List[object]
    $running = 0
    $peak = 0
    $peakMinute = $null

    $t = Get-Date $MonthStartUtc -Second 0 -Millisecond 0
    $end = Get-Date $MonthEndUtc -Second 0 -Millisecond 0

    while ($t -lt $end) {
        if ($delta.ContainsKey($t)) { $running += $delta[$t] }

        if ($running -gt $peak) {
            $peak = $running
            $peakMinute = $t
        }

        $series.Add([pscustomobject]@{
            MinuteUtc    = $t.ToString("yyyy-MM-ddTHH:mm:00Z")
            Concurrent   = $running
        })

        $t = $t.AddMinutes(1)
    }

    return [pscustomobject]@{
        PeakConcurrent = $peak
        PeakMinuteUtc  = $peakMinute
        Series         = $series
    }
}

# -----------------------------
# Main
# -----------------------------
$OutputDir = New-OutputFolder -Base $OutputDir
Write-Host "Output: $($OutputDir)" -ForegroundColor Green

$apiBase = "https://api.$($Environment)"

$month = Get-MonthIntervalUtc -Ym $YearMonth
Write-Host "Month UTC interval: $((ConvertTo-UtcIsoZ $month.StartUtc)) / $((ConvertTo-UtcIsoZ $month.EndUtc))" -ForegroundColor Green

$token = Get-GCAccessToken -Env $Environment -Id $ClientId -Secret $ClientSecret
Write-Host "Auth: token acquired." -ForegroundColor Green

# Build chunk intervals
$chunks = New-Object System.Collections.Generic.List[object]
$cur = $month.StartUtc
while ($cur -lt $month.EndUtc) {
    $next = $cur.AddDays($ChunkDays)
    if ($next -gt $month.EndUtc) { $next = $month.EndUtc }

    $chunks.Add([pscustomobject]@{
        StartUtc = $cur
        EndUtc   = $next
        Interval = "{0}/{1}" -f (ConvertTo-UtcIsoZ $cur), (ConvertTo-UtcIsoZ $next)
    })

    $cur = $next
}

Write-Host "Plan: $($chunks.Count) async job chunk(s) of up to $($ChunkDays) day(s) each." -ForegroundColor Green

# Dedup store: session key -> merged interval
$dedup = @{}  # key => object with StartUtc/EndUtc/etc

for ($i = 0; $i -lt $chunks.Count; $i++) {
    $c = $chunks[$i]
    Write-Host "`n==== Chunk $($i+1)/$($chunks.Count): $($c.Interval) ====" -ForegroundColor Magenta

    $job = New-GCConversationDetailsJob -ApiBase $apiBase -AccessToken $token -IntervalIso $c.Interval
    $jobId = [string]$job.id
    if (-not $jobId) { throw "Job create response missing id." }

    Write-Host "Job: created id=$($jobId)" -ForegroundColor Cyan

    # Poll status
    while ($true) {
        $st = Get-GCConversationDetailsJobStatus -ApiBase $apiBase -AccessToken $token -JobId $jobId
        $state = if ($st.PSObject.Properties.Name -contains 'state') { [string]$st.state } else { "" }
        $pct   = if ($st.PSObject.Properties.Name -contains 'percentComplete') { [int]$st.percentComplete } else { $null }

        $msg = "Job $($jobId): state=$($state)"
        if ($pct -ne $null) { $msg += " pct=$($pct)%" }
        Write-Host $msg -ForegroundColor DarkCyan

        if ($state -match '(?i)fulfilled|completed') { break }
        if ($state -match '(?i)failed|canceled|cancelled') {
            throw "Job $($jobId) ended in state=$($state)"
        }

        Start-Sleep -Seconds $PollSeconds
    }

    # Fetch results
    $convos = Get-GCConversationDetailsJobResultsAll -ApiBase $apiBase -AccessToken $token -JobId $jobId -PageSize $PageSize
    Write-Host "Job $($jobId): fetched $($convos.Count) conversation record(s)." -ForegroundColor Cyan

    # Extract + merge trunk intervals
    $extractedCount = 0
    foreach ($conv in $convos) {
        $ivals = Extract-TrunkIntervals -ConversationRecord $conv -LooseTelOnly:$LooseTelOnly
        foreach ($iv in $ivals) {
            $extractedCount++

            $k = "{0}|{1}|{2}" -f $iv.ConversationId, $iv.ParticipantId, $iv.SessionId
            if (-not $dedup.ContainsKey($k)) {
                $dedup[$k] = $iv
            }
            else {
                # Merge (keep earliest start and latest end)
                $curIv = $dedup[$k]
                if ([datetime]$iv.StartUtc -lt [datetime]$curIv.StartUtc) { $curIv.StartUtc = $iv.StartUtc }
                if ([datetime]$iv.EndUtc   -gt [datetime]$curIv.EndUtc)   { $curIv.EndUtc   = $iv.EndUtc }
            }
        }
    }

    Write-Host "Chunk $($i+1): extracted $($extractedCount) trunk-interval candidate(s); dedup now $($dedup.Count)." -ForegroundColor Green
}

# Final interval list
$finalIntervals = @($dedup.Values)

Write-Host "`nTotal deduped trunk intervals: $($finalIntervals.Count)" -ForegroundColor Green

# Save intervals (show-your-work)
$intervalsPath = [System.IO.Path]::Combine($OutputDir, "Intervals_TrunkVoice_NoWrapup.csv")
$finalIntervals | Sort-Object StartUtc | Export-Csv -NoTypeInformation -Path $intervalsPath
Write-Host "Wrote: $($intervalsPath)" -ForegroundColor Green

# Compute peak + time series
Write-Host "`nComputing minute-by-minute concurrency series..." -ForegroundColor Cyan
$result = Get-PeakConcurrentMinuteSeries -Intervals $finalIntervals -MonthStartUtc $month.StartUtc -MonthEndUtc $month.EndUtc

$peakMinute = $result.PeakMinuteUtc
$peakVal    = $result.PeakConcurrent

Write-Host "PEAK CONCURRENT TRUNK CALLS: $($peakVal)" -ForegroundColor Green
Write-Host "PEAK MINUTE (UTC): $($peakMinute.ToString('yyyy-MM-ddTHH:mm:00Z'))" -ForegroundColor Green

# Save series
$seriesPath = [System.IO.Path]::Combine($OutputDir, "MinuteSeries_Concurrency.csv")
$result.Series | Export-Csv -NoTypeInformation -Path $seriesPath
Write-Host "Wrote: $($seriesPath)" -ForegroundColor Green

# Save summary JSON
$summary = [pscustomobject]@{
    Environment        = $Environment
    YearMonth          = $YearMonth
    MonthStartUtc      = (ConvertTo-UtcIsoZ $month.StartUtc)
    MonthEndUtc        = (ConvertTo-UtcIsoZ $month.EndUtc)
    ChunkDays          = $ChunkDays
    PageSize           = $PageSize
    IntervalCount      = $finalIntervals.Count
    PeakConcurrent     = $peakVal
    PeakMinuteUtc      = $peakMinute.ToString('yyyy-MM-ddTHH:mm:00Z')
    FilterMode         = if ($LooseTelOnly) { "tel/tel only" } else { "tel/tel + external/customer guard" }
}

$summaryPath = [System.IO.Path]::Combine($OutputDir, "Summary.json")
$summary | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 -FilePath $summaryPath
Write-Host "Wrote: $($summaryPath)" -ForegroundColor Green

Write-Host "`nDone." -ForegroundColor Green
### END FILE: Get-GCPeakTrunkConcurrency.ps1
