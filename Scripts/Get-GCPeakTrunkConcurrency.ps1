<#
.SYNOPSIS
  Computes Peak Concurrent external-trunk voice calls over a time interval (typically a month),
  excluding wrapup time by ending the interval at wrapup.segmentStart.

.DESCRIPTION
  - Uses Analytics Conversation Details Async Jobs:
      POST  /api/v2/analytics/conversations/details/jobs
      GET   /api/v2/analytics/conversations/details/jobs/{jobId}
      GET   /api/v2/analytics/conversations/details/jobs/{jobId}/results?cursor=...

  - Pages results until cursor is absent.
  - Monitors inin-ratelimit-* headers and sleeps when near limit.
  - Shows work by optionally exporting every trunk-leg interval to CSV.

  External-trunk leg identification (purpose-agnostic):
    - session.mediaType = voice
    - session.ani and session.dnis start with 'tel:'
    - session.peerId is null/missing (root leg)
    - optional: session.edgeId must be in allow-list

.PARAMETER AccessToken
  OAuth bearer token (no "Bearer " prefix required).

.PARAMETER BaseUri
  Region base, e.g. https://api.usw2.pure.cloud

.PARAMETER IntervalStartUtc
  Interval start in UTC (DateTime). Example: 2025-11-01 00:00:00Z

.PARAMETER IntervalEndUtc
  Interval end in UTC (DateTime). Example: 2025-12-01 00:00:00Z

.PARAMETER ChunkDays
  Subdivide the interval into smaller job intervals to reduce payload size/timeouts.

.PARAMETER EdgeIdAllowList
  Optional array of edgeIds to include. This is the practical replacement for "filter on IPs".

.PARAMETER ExportIntervalsCsv
  Optional path to write per-session computed intervals (shows work).

.EXAMPLE
  .\Get-GCPeakTrunkConcurrency.ps1 `
    -AccessToken $env:GC_TOKEN `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -IntervalStartUtc ([datetime]'2025-11-01T00:00:00Z') `
    -IntervalEndUtc   ([datetime]'2025-12-01T00:00:00Z') `
    -ChunkDays 1 `
    -ExportIntervalsCsv '.\trunk-intervals.csv'
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$AccessToken,

  [Parameter(Mandatory)]
  [string]$BaseUri,

  [Parameter(Mandatory)]
  [datetime]$IntervalStartUtc,

  [Parameter(Mandatory)]
  [datetime]$IntervalEndUtc,

  [int]$ChunkDays = 1,

  [string[]]$EdgeIdAllowList = @(),

  [string]$ExportIntervalsCsv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\tools\Import-LocalOpsInsights.ps1')

#region Helpers

function Parse-GcUtc {
  param([Parameter(Mandatory)][string]$Value)
  # Genesys returns ISO-8601 Zulu timestamps; parse to UTC DateTime.
  return [datetime]::Parse(
    $Value,
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
  )
}

function Floor-ToMinuteUtc {
  param([Parameter(Mandatory)][datetime]$Utc)
  return [datetime]::SpecifyKind(
    (New-Object datetime($Utc.Year, $Utc.Month, $Utc.Day, $Utc.Hour, $Utc.Minute, 0)),
    [System.DateTimeKind]::Utc
  )
}

function Ceil-ToMinuteUtc {
  param([Parameter(Mandatory)][datetime]$Utc)
  $flo = Floor-ToMinuteUtc -Utc $Utc
  if ($Utc -gt $flo) { return $flo.AddMinutes(1) }
  return $flo
}

function Invoke-GcApi {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('GET','POST')]
    [string]$Method,

    [Parameter(Mandatory)]
    [string]$Path,

    [object]$Body,

    [hashtable]$Query
  )

  $uri = "$($BaseUri)$($Path)"
  if ($Query -and $Query.Count -gt 0) {
    $qs = ($Query.GetEnumerator() | ForEach-Object {
      "$([uri]::EscapeDataString($_.Key))=$([uri]::EscapeDataString([string]$_.Value))"
    }) -join '&'
    $uri = "$($uri)?$($qs)"
  }

  $headers = @{
    'Authorization' = "Bearer $($AccessToken)"
    'Accept'        = 'application/json'
  }

  $payload = $Body
  if ($Method -eq 'POST' -and $null -ne $Body -and -not ($Body -is [string])) {
    $payload = ($Body | ConvertTo-Json -Depth 50)
  }

  Invoke-GCRequest -Method $Method -Uri $uri -Headers $headers -Body $payload
}

function New-IntervalCursorRow {
  param(
    [string]$ConversationId,
    [string]$SessionId,
    [string]$EdgeId,
    [datetime]$StartUtc,
    [datetime]$EndUtc
  )

  [pscustomobject]@{
    conversationId = $ConversationId
    sessionId      = $SessionId
    edgeId         = $EdgeId
    startUtc       = $StartUtc.ToString('o')
    endUtc         = $EndUtc.ToString('o')
    durationSec    = [math]::Round(($EndUtc - $StartUtc).TotalSeconds, 3)
  }
}

#endregion Helpers

#region Minute-bucket diff array (fast concurrency math)

if ($IntervalEndUtc -le $IntervalStartUtc) {
  throw "IntervalEndUtc must be greater than IntervalStartUtc."
}

$monthStart = [datetime]::SpecifyKind($IntervalStartUtc, [System.DateTimeKind]::Utc)
$monthEnd   = [datetime]::SpecifyKind($IntervalEndUtc,   [System.DateTimeKind]::Utc)

$totalMinutes = [int][math]::Ceiling(($monthEnd - $monthStart).TotalMinutes)
# diff array length is totalMinutes + 1 so we can safely decrement at endExclusiveIndex == totalMinutes
$diff = New-Object int[] ($totalMinutes + 1)

$intervalRows = New-Object System.Collections.Generic.List[object]

#endregion Minute-bucket diff array

#region Chunk loop

$chunkSpan = [timespan]::FromDays([math]::Max(1, $ChunkDays))
$chunkStart = $monthStart
$chunkIndex = 0

while ($chunkStart -lt $monthEnd) {
  $chunkIndex++
  $chunkEnd = $chunkStart.Add($chunkSpan)
  if ($chunkEnd -gt $monthEnd) { $chunkEnd = $monthEnd }

  $intervalStr = "$($chunkStart.ToString('o'))/$($chunkEnd.ToString('o'))"
  Write-Host "🔎 Chunk $($chunkIndex): $($intervalStr)" -ForegroundColor Cyan

  # Build async conversation details job query (filter to voice via segmentFilters)
  $jobBody = @{
    interval    = $intervalStr
    order       = 'asc'
    orderBy     = 'conversationStart'
    segmentFilters = @(
      @{
        type = 'and'
        predicates = @(
          @{ type = 'dimension'; dimension = 'mediaType'; value = 'voice' }
        )
      }
    )
  }

  $job = Invoke-GcApi -Method POST -Path '/api/v2/analytics/conversations/details/jobs' -Body $jobBody
  $jobId = $job.id
  if ([string]::IsNullOrWhiteSpace($jobId)) { throw "Job id not returned for interval $($intervalStr)" }

  Write-Host "🧾 JobId: $($jobId) (polling...)" -ForegroundColor DarkCyan

  # Poll job status
  while ($true) {
    Start-Sleep -Seconds 2
    $jobStatus = Invoke-GcApi -Method GET -Path "/api/v2/analytics/conversations/details/jobs/$($jobId)"
    $state = $jobStatus.state
    if ([string]::IsNullOrWhiteSpace($state)) { $state = $jobStatus.status } # defensive

    Write-Host "   ↳ State: $($state)" -ForegroundColor DarkGray

    if ($state -match 'FULFILLED|COMPLETED') { break }
    if ($state -match 'FAILED|ERROR') {
      throw "Job $($jobId) failed. State=$($state)"
    }
  }

  # Page results until no cursor
  $cursor = $null
  $pageNum = 0
  $processedConversations = 0

  do {
    $pageNum++
    $q = @{}
    if ($cursor) { $q['cursor'] = $cursor }

    Write-Host "   📦 Fetching results page $($pageNum) (cursor=$($cursor))" -ForegroundColor DarkGray

    $page = Invoke-GcApi -Method GET -Path "/api/v2/analytics/conversations/details/jobs/$($jobId)/results" -Query $q

    $conversations = @()
    if ($page.conversations) { $conversations = $page.conversations }
    $cursor = $page.cursor

    foreach ($conv in $conversations) {
      $processedConversations++

      $convId = $conv.conversationId
      if ([string]::IsNullOrWhiteSpace($convId)) { $convId = $conv.id }

      # Build a set of peerIds used in this conversation (optional sanity checks)
      $peerIds = New-Object 'System.Collections.Generic.HashSet[string]'
      foreach ($p in @($conv.participants)) {
        foreach ($s in @($p.sessions)) {
          if ($s.PSObject.Properties.Name -contains 'peerId') {
            if (-not [string]::IsNullOrWhiteSpace($s.peerId)) { [void]$peerIds.Add([string]$s.peerId) }
          }
        }
      }

      foreach ($p in @($conv.participants)) {
        foreach ($s in @($p.sessions)) {

          # ---- External trunk root-leg filter (purpose-agnostic) ----
          if ($s.mediaType -ne 'voice') { continue }
          if (-not ($s.ani  -is [string] -and $s.ani  -like 'tel:*')) { continue }
          if (-not ($s.dnis -is [string] -and $s.dnis -like 'tel:*')) { continue }

          # Root-leg heuristic: peerId must be missing/empty
          $hasPeerProp = ($s.PSObject.Properties.Name -contains 'peerId')
          if ($hasPeerProp -and (-not [string]::IsNullOrWhiteSpace([string]$s.peerId))) { continue }

          if ($s.provider -and $s.provider -ne 'Edge') { continue }

          $edgeId = [string]$s.edgeId
          if ($EdgeIdAllowList.Count -gt 0) {
            if ([string]::IsNullOrWhiteSpace($edgeId)) { continue }
            if ($EdgeIdAllowList -notcontains $edgeId) { continue }
          }

          # Optional extra guard: root sessionId is commonly referenced by other sessions' peerId
          # (If you find edge cases where this drops valid trunk legs, comment it out.)
          $sessionId = [string]$s.sessionId
          if (-not [string]::IsNullOrWhiteSpace($sessionId)) {
            if (-not $peerIds.Contains($sessionId)) {
              # Keep it permissive by default; comment next line IN if you want strict "must-have-child" behavior.
              # continue
              $null = $null
            }
          }

          # ---- Compute interval excluding wrapup ----
          $startUtc = $null
          $endUtc   = $null

          $segments = @()
          if ($s.segments) { $segments = @($s.segments) }

          if ($segments.Count -gt 0) {
            # Sort by segmentStart
            $segmentsSorted = $segments | Sort-Object { Parse-GcUtc -Value $_.segmentStart }

            $startUtc = Parse-GcUtc -Value $segmentsSorted[0].segmentStart

            # If wrapup exists, end at wrapup.segmentStart; else max(segmentEnd)
            $wrap = $segmentsSorted | Where-Object { $_.segmentType -eq 'wrapup' } | Select-Object -First 1
            if ($wrap) {
              $endUtc = Parse-GcUtc -Value $wrap.segmentStart
            } else {
              $maxEnd = $null
              foreach ($seg in $segmentsSorted) {
                if ($seg.segmentEnd) {
                  $t = Parse-GcUtc -Value $seg.segmentEnd
                  if (-not $maxEnd -or $t -gt $maxEnd) { $maxEnd = $t }
                }
              }
              $endUtc = $maxEnd
            }
          }

          # Fallbacks if segments are missing
          if (-not $startUtc) {
            if ($conv.conversationStart) { $startUtc = Parse-GcUtc -Value $conv.conversationStart }
          }
          if (-not $endUtc) {
            if ($conv.conversationEnd) { $endUtc = Parse-GcUtc -Value $conv.conversationEnd }
          }

          if (-not $startUtc -or -not $endUtc) { continue }
          if ($endUtc -le $startUtc) { continue }

          # Export "show your work" row
          if ($ExportIntervalsCsv) {
            $intervalRows.Add((New-IntervalCursorRow -ConversationId $convId -SessionId $sessionId -EdgeId $edgeId -StartUtc $startUtc -EndUtc $endUtc)) | Out-Null
          }

          # Minute bucket math: count if interval intersects the minute bucket.
          # Use [startFloor, endCeil) in minutes.
          $startBucket = Floor-ToMinuteUtc -Utc $startUtc
          $endBucketEx = Ceil-ToMinuteUtc  -Utc $endUtc

          if ($endBucketEx -le $startBucket) { continue }

          $startIndex = [int][math]::Floor(($startBucket - $monthStart).TotalMinutes)
          $endIndexEx = [int][math]::Floor(($endBucketEx - $monthStart).TotalMinutes)

          if ($startIndex -lt 0) { $startIndex = 0 }
          if ($endIndexEx -gt $totalMinutes) { $endIndexEx = $totalMinutes }

          if ($endIndexEx -le $startIndex) { continue }

          $diff[$startIndex]++
          $diff[$endIndexEx]--
        }
      }

      if (($processedConversations % 250) -eq 0) {
        Write-Host "   … processed $($processedConversations) conversations (chunk $($chunkIndex))" -ForegroundColor DarkGray
      }
    }

  } while ($cursor)

  Write-Host "✅ Chunk $($chunkIndex) complete. Conversations processed: $($processedConversations)" -ForegroundColor Green

  $chunkStart = $chunkEnd
}

#endregion Chunk loop

#region Final reduce: diff -> concurrency + peak

$running = 0
$peak = 0
$peakMinuteIndex = 0

for ($i = 0; $i -lt $totalMinutes; $i++) {
  $running += $diff[$i]
  if ($running -gt $peak) {
    $peak = $running
    $peakMinuteIndex = $i
  }
}

$peakMinuteUtc = $monthStart.AddMinutes($peakMinuteIndex)

Write-Host ""
Write-Host "🏁 Peak Concurrent External Trunk Calls: $($peak)" -ForegroundColor Magenta
Write-Host "🕒 Peak Minute (UTC): $($peakMinuteUtc.ToString('o'))" -ForegroundColor Magenta

# Export "show your work" CSV (optional)
if ($ExportIntervalsCsv) {
  $outPath = [System.IO.Path]::GetFullPath($ExportIntervalsCsv)
  $dir = [System.IO.Path]::GetDirectoryName($outPath)
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }

  $intervalRows
  | Sort-Object startUtc
  | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $outPath

  Write-Host "🧾 Intervals exported: $($outPath)" -ForegroundColor Cyan
}

# Return a structured object too
[pscustomobject]@{
  intervalStartUtc = $monthStart.ToString('o')
  intervalEndUtc   = $monthEnd.ToString('o')
  peakConcurrent   = $peak
  peakMinuteUtc    = $peakMinuteUtc.ToString('o')
  chunkDays        = $ChunkDays
  edgeIdAllowList  = $EdgeIdAllowList
}

#endregion Final reduce
