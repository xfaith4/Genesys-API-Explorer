# GenesysCloud.ConversationToolkit - Complete Reference

## Overview

The **GenesysCloud.ConversationToolkit** is a comprehensive PowerShell module designed for Genesys Cloud engineers to analyze conversation details, extract MediaEndpointStats, identify WebRTC errors, troubleshoot routing issues, and generate professional Excel reports.

This toolkit is a central feature of the Genesys-API-Explorer project, providing enterprise-grade conversation analytics and reporting capabilities.

## Key Features

### 1. Multi-Source Data Aggregation
- Combines data from 6 different Genesys Cloud API endpoints
- Correlates all data via ConversationId
- Creates unified timeline views with chronological ordering

### 2. Professional Excel Export
- Elegant formatting with TableStyle Light11
- AutoFilter and AutoSize for optimal presentation
- Multiple worksheets for different data perspectives
- MediaEndpointStats extraction for quality analysis
- WebRTC error tracking and reporting

### 3. Conversation Analysis
- Timeline-based event visualization
- Participant tracking across all segments
- Queue routing analysis
- Error and disconnect type identification
- Sentiment and speech analytics integration

### 4. Performance Monitoring
- Queue smoke reports with abandon/error rates
- Agent performance metrics
- Hot conversation detection (suspicious/problematic calls)
- SIP message analysis for telephony issues

## Installation

### Prerequisites

1. **PowerShell 5.1+** or **PowerShell Core 7+**
2. **ImportExcel Module** (for Excel export functionality)

```powershell
# Install ImportExcel module
Install-Module ImportExcel -Scope CurrentUser -Force
```

3. **Genesys Cloud OAuth Token** with appropriate permissions:
   - `conversations:readonly`
   - `analytics:readonly`
   - `speechandtextanalytics:readonly`
   - `recording:readonly`
   - `telephony:readonly`

### Module Import

```powershell
# Import the module
Import-Module /path/to/GenesysCloud.ConversationToolkit/GenesysCloud.ConversationToolkit.psd1
```

## Exported Functions

The module exports 6 main functions:

1. **Get-GCConversationTimeline** - Comprehensive conversation data aggregation
2. **Export-GCConversationToExcel** - Professional Excel report generation
3. **Get-GCQueueSmokeReport** - Queue performance and error analysis
4. **Get-GCQueueHotConversations** - Identify problematic conversations
5. **Show-GCConversationTimelineUI** - WPF-based interactive timeline viewer
6. **Invoke-GCSmokeDrill** - End-to-end investigation workflow

## Function Reference

### Get-GCConversationTimeline

Pulls comprehensive conversation data from multiple Genesys Cloud APIs and normalizes it into a unified timeline.

#### API Endpoints Called
- `GET /api/v2/conversations/{conversationId}` - Core conversation details
- `GET /api/v2/analytics/conversations/{conversationId}/details` - Analytics data with MediaEndpointStats
- `GET /api/v2/speechandtextanalytics/conversations/{conversationId}` - Speech analytics
- `GET /api/v2/conversations/{conversationId}/recordingmetadata` - Recording metadata
- `GET /api/v2/speechandtextanalytics/conversations/{conversationId}/sentiments` - Sentiment analysis
- `GET /api/v2/telephony/sipmessages/conversations/{conversationId}` - SIP messages

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| BaseUri | string | Yes | Base API URI (e.g., https://api.usw2.pure.cloud) |
| AccessToken | string | Yes | OAuth Bearer token |
| ConversationId | string | Yes | Target conversation ID |

#### Output Structure

Returns a PSCustomObject with:
- **ConversationId** - The conversation identifier
- **Core** - Raw core conversation data
- **AnalyticsDetails** - Raw analytics details with MediaEndpointStats
- **SpeechText** - Speech analytics data
- **RecordingMeta** - Recording metadata
- **Sentiments** - Sentiment analysis data
- **SipMessages** - SIP message logs
- **TimelineEvents** - Normalized, chronologically sorted event list

#### TimelineEvents Structure

Each timeline event includes:
- **ConversationId** - Ties all events together
- **StartTime** - Event start timestamp (DateTime)
- **EndTime** - Event end timestamp (DateTime, nullable)
- **Source** - Data source (Core, Analytics, SpeechText, Recording, Sentiment, SIP)
- **EventType** - Type of event (e.g., interact, alert, wrapup, Topic, Recording)
- **Participant** - Participant ID or name
- **Queue** - Queue ID if applicable
- **User** - User ID if applicable
- **Direction** - Direction (inbound, outbound)
- **DisconnectType** - Disconnect reason
- **Extra** - Hashtable with additional source-specific properties

#### Example Usage

```powershell
# Basic usage
$timeline = Get-GCConversationTimeline `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -AccessToken $token `
    -ConversationId 'abc123-def456-ghi789'

# View event count
Write-Host "Total events: $($timeline.TimelineEvents.Count)"

# View timeline events sorted chronologically
$timeline.TimelineEvents | Format-Table StartTime, Source, EventType, Participant, Queue, DisconnectType -AutoSize

# Access raw analytics data
$timeline.AnalyticsDetails | ConvertTo-Json -Depth 10

# Check for WebRTC errors
$webRtcErrors = $timeline.TimelineEvents | 
    Where-Object { $_.Extra.ErrorCode -match 'webrtc|media|rtp' }
$webRtcErrors | Format-Table StartTime, EventType, Participant, @{L='ErrorCode';E={$_.Extra.ErrorCode}}
```

### Export-GCConversationToExcel

Exports conversation timeline data to a professionally formatted Excel workbook with multiple worksheets.

#### Features
- **TableStyle Light11** - Elegant, professional table formatting
- **AutoFilter** - Enable filtering on all columns
- **AutoSize** - Automatically adjust column widths
- **Freeze Top Row** - Keep headers visible while scrolling
- **Bold Headers** - Clear visual hierarchy
- **Multiple Worksheets** - Separate tabs for different data views

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| ConversationData | PSCustomObject | Yes | Output from Get-GCConversationTimeline |
| OutputPath | string | No | Full path to output Excel file (auto-generated if not provided) |
| IncludeRawData | switch | No | Include additional worksheets with raw data |

#### Worksheets Generated

**Always Included:**
- **Timeline Events** - Flattened timeline with all events chronologically sorted

**Included with -IncludeRawData:**
- **Core Conversation** - Core API participant and segment data
- **Analytics Details** - Analytics segments with error codes
- **Media Stats** - MediaEndpointStats for quality analysis (MOS scores, packet loss, jitter)
- **SIP Messages** - Raw SIP signaling messages
- **Sentiment Analysis** - Sentiment scores over time

#### Example Usage

```powershell
# Basic export with timeline only
$timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId
Export-GCConversationToExcel -ConversationData $timeline

# Custom path with all data
$timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId
Export-GCConversationToExcel `
    -ConversationData $timeline `
    -OutputPath "C:\Reports\Investigation_$convId.xlsx" `
    -IncludeRawData

# Pipeline usage
Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId |
    Export-GCConversationToExcel -OutputPath "C:\Reports\Conversation.xlsx" -IncludeRawData
```

### Get-GCQueueSmokeReport

Generates a "smoke detector" report for queue and agent performance using conversation aggregate metrics.

#### API Endpoint Called
- `POST /api/v2/analytics/conversations/aggregates/query` - Called twice (queue grouping, agent grouping)

#### Metrics Analyzed
- **nOffered** - Conversations offered
- **nAnswered** - Conversations answered
- **nAbandoned** - Conversations abandoned
- **nError** - Conversations with errors
- **tHandle** - Total handle time
- **tTalk** - Total talk time
- **tWait** - Total wait time

#### Calculated Indicators
- **AbandonRate** - (nAbandoned / nOffered) × 100
- **ErrorRate** - (nError / nOffered) × 100
- **AvgHandle** - Average handle time in seconds
- **AvgTalk** - Average talk time in seconds
- **AvgWait** - Average wait time in seconds

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| BaseUri | string | Yes | Base API URI |
| AccessToken | string | Yes | OAuth Bearer token |
| Interval | string | Yes | Analytics interval (ISO 8601 format) |
| DivisionId | string | No | Optional division filter |
| QueueIds | string[] | No | Optional queue ID filter |
| TopN | int | No | Number of top queues/agents to return (default: 10) |

#### Output Structure

Returns a PSCustomObject with:
- **Interval** - The query interval
- **QueueSummary** - All queue statistics
- **QueueTop** - Top N queues by abandon/error rate
- **AgentSummary** - All agent statistics
- **AgentTop** - Top N agents by abandon/error rate

#### Example Usage

```powershell
# Last 7 days queue performance
$interval = "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z"
$report = Get-GCQueueSmokeReport `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -AccessToken $token `
    -Interval $interval `
    -TopN 20

# View top problematic queues
$report.QueueTop | Format-Table QueueId, Offered, AbandonRate, ErrorRate, AvgWait -AutoSize

# Export to Excel
$report.QueueTop | Export-Excel -Path "QueueReport.xlsx" -TableStyle Light11 -AutoFilter -AutoSize
```

### Get-GCQueueHotConversations

Identifies the "hottest" (most problematic) conversations for a specific queue.

#### Detection Criteria (Smoke Score)
- **Error Disconnects** - Weighted × 3 (non-client, non-endpoint disconnects)
- **Short Calls** - Weighted × 2 (inbound interactions < 15 seconds)
- **Queue Segments** - Weighted × 1 (multiple queue hops)

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| BaseUri | string | Yes | Base API URI |
| AccessToken | string | Yes | OAuth Bearer token |
| QueueId | string | Yes | Queue ID to analyze |
| Interval | string | Yes | Analytics interval |
| PageSize | int | No | Max conversations to retrieve (default: 200) |
| TopN | int | No | Number of hot conversations to return (default: 25) |

#### Example Usage

```powershell
$hotConvs = Get-GCQueueHotConversations `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -AccessToken $token `
    -QueueId 'queue-abc-123' `
    -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' `
    -TopN 50

# View hottest conversations
$hotConvs | Format-Table ConversationId, SmokeScore, ErrorSegments, ShortCalls, StartTime -AutoSize

# Investigate top conversation
$topConv = $hotConvs | Select-Object -First 1
$timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $topConv.ConversationId
Export-GCConversationToExcel -ConversationData $timeline -IncludeRawData
```

### Show-GCConversationTimelineUI

Launches a WPF-based interactive timeline viewer for conversations.

#### Features
- Input field for conversation ID
- Load button to fetch timeline data
- DataGrid with sortable columns
- Auto-load support when conversation ID provided

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| BaseUri | string | Yes | Base API URI |
| AccessToken | string | Yes | OAuth Bearer token |
| ConversationId | string | No | Optional conversation ID to auto-load |

#### Example Usage

```powershell
# Interactive mode - user enters conversation ID
Show-GCConversationTimelineUI `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -AccessToken $token

# Auto-load specific conversation
Show-GCConversationTimelineUI `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -AccessToken $token `
    -ConversationId 'abc-123-def-456'
```

### Invoke-GCSmokeDrill

End-to-end investigation workflow combining queue analysis, hot conversation detection, and timeline visualization.

#### Workflow
1. Generate queue smoke report
2. Present queue selector (Out-GridView)
3. Find hot conversations for selected queue
4. Present conversation selector (Out-GridView)
5. Launch timeline UI for selected conversation

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| BaseUri | string | Yes | Base API URI |
| AccessToken | string | Yes | OAuth Bearer token |
| Interval | string | Yes | Analytics interval |
| DivisionId | string | No | Optional division filter |
| QueueIds | string[] | No | Optional queue ID filter |
| TopNQueues | int | No | Top queues to show (default: 10) |
| TopNConversations | int | No | Top conversations to show (default: 25) |

#### Example Usage

```powershell
# Complete investigation workflow
Invoke-GCSmokeDrill `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -AccessToken $token `
    -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' `
    -TopNQueues 20 `
    -TopNConversations 50
```

## Common Workflows

### Workflow 1: Single Conversation Deep Dive

```powershell
# Import module
Import-Module GenesysCloud.ConversationToolkit

# Set credentials
$baseUri = 'https://api.usw2.pure.cloud'
$token = 'your-oauth-token-here'
$convId = 'conversation-id-here'

# Pull all conversation data
$timeline = Get-GCConversationTimeline `
    -BaseUri $baseUri `
    -AccessToken $token `
    -ConversationId $convId

# Generate comprehensive Excel report
Export-GCConversationToExcel `
    -ConversationData $timeline `
    -OutputPath "C:\Reports\Conversation_$convId.xlsx" `
    -IncludeRawData

# Open Excel file
Invoke-Item "C:\Reports\Conversation_$convId.xlsx"
```

### Workflow 2: Queue Health Check

```powershell
# Generate queue smoke report
$interval = "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z"
$report = Get-GCQueueSmokeReport `
    -BaseUri $baseUri `
    -AccessToken $token `
    -Interval $interval `
    -TopN 20

# Export problematic queues
$report.QueueTop | 
    Where-Object { $_.AbandonRate -gt 10 -or $_.ErrorRate -gt 5 } |
    Export-Excel -Path "ProblematicQueues.xlsx" -TableStyle Light11 -AutoFilter -AutoSize

# Investigate each problematic queue
foreach ($queue in $report.QueueTop | Select-Object -First 5) {
    $hotConvs = Get-GCQueueHotConversations `
        -BaseUri $baseUri `
        -AccessToken $token `
        -QueueId $queue.QueueId `
        -Interval $interval `
        -TopN 10
    
    Write-Host "Queue $($queue.QueueId): $($hotConvs.Count) hot conversations found"
}
```

### Workflow 3: WebRTC Error Analysis

```powershell
# Pull conversation
$timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId

# Extract WebRTC errors
$webRtcErrors = $timeline.TimelineEvents | Where-Object {
    $_.Extra.ErrorCode -match 'webrtc|media|ice|stun|turn|rtp|codec' -or
    $_.Extra.MediaType -and $_.DisconnectType -notin @('client','endpoint','peer')
}

# Analyze error patterns
$errorSummary = $webRtcErrors | 
    Group-Object { $_.Extra.ErrorCode } | 
    Select-Object Count, Name | 
    Sort-Object Count -Descending

$errorSummary | Format-Table -AutoSize

# Export detailed report
$webRtcErrors | 
    Select-Object StartTime, EventType, Participant, Direction, DisconnectType, 
                  @{L='ErrorCode';E={$_.Extra.ErrorCode}},
                  @{L='MediaType';E={$_.Extra.MediaType}} |
    Export-Excel -Path "WebRTC_Errors_$convId.xlsx" -TableStyle Light11 -AutoFilter -AutoSize
```

### Workflow 4: MediaEndpointStats Quality Analysis

```powershell
# Pull conversation with analytics
$timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId

# Export with media stats
Export-GCConversationToExcel `
    -ConversationData $timeline `
    -OutputPath "Quality_Analysis_$convId.xlsx" `
    -IncludeRawData

# Extract quality metrics from analytics
if ($timeline.AnalyticsDetails.participants) {
    foreach ($participant in $timeline.AnalyticsDetails.participants) {
        foreach ($session in $participant.sessions) {
            if ($session.metrics) {
                $mosMetrics = $session.metrics | Where-Object { $_.name -match 'mos|quality' }
                $packetLoss = $session.metrics | Where-Object { $_.name -match 'packet.*loss' }
                $jitter = $session.metrics | Where-Object { $_.name -match 'jitter' }
                
                Write-Host "Participant: $($participant.participantId)"
                Write-Host "  MOS Scores: $($mosMetrics.value -join ', ')"
                Write-Host "  Packet Loss: $($packetLoss.value -join ', ')"
                Write-Host "  Jitter: $($jitter.value -join ', ')"
            }
        }
    }
}
```

### Workflow 5: Routing Issue Investigation

```powershell
# Pull timeline
$timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId

# Analyze queue routing
$queueEvents = $timeline.TimelineEvents | Where-Object { $_.Queue }
$uniqueQueues = $queueEvents.Queue | Select-Object -Unique

Write-Host "Conversation routed through $($uniqueQueues.Count) queue(s):"
$uniqueQueues | ForEach-Object { Write-Host "  - $_" }

# Find transfers
$transfers = $timeline.TimelineEvents | Where-Object { 
    $_.Extra.TransferType -or 
    $_.EventType -eq 'transfer' 
}

Write-Host "`nTransfers detected: $($transfers.Count)"
$transfers | Format-Table StartTime, EventType, Participant, Queue, @{L='TransferType';E={$_.Extra.TransferType}} -AutoSize

# Identify routing delays
$queueWaitEvents = $timeline.TimelineEvents | Where-Object { 
    $_.EventType -eq 'alert' -or $_.EventType -eq 'dialing' 
}

foreach ($wait in $queueWaitEvents) {
    if ($wait.StartTime -and $wait.EndTime) {
        $duration = $wait.EndTime - $wait.StartTime
        Write-Host "Queue wait: $($duration.TotalSeconds) seconds in $($wait.Queue)"
    }
}
```

## Best Practices

### 1. Token Management
- Use short-lived OAuth tokens
- Never commit tokens to source control
- Refresh tokens before long-running operations

### 2. Error Handling
```powershell
try {
    $timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId
} catch {
    Write-Error "Failed to retrieve conversation: $($_.Exception.Message)"
    Write-Error "Status Code: $($_.Exception.Response.StatusCode.value__)"
}
```

### 3. Bulk Operations
```powershell
# Process multiple conversations
$conversationIds = @('conv1', 'conv2', 'conv3')
$results = @()

foreach ($convId in $conversationIds) {
    Write-Progress -Activity "Processing Conversations" -Status $convId -PercentComplete (($results.Count / $conversationIds.Count) * 100)
    
    try {
        $timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId
        $export = Export-GCConversationToExcel -ConversationData $timeline -IncludeRawData
        $results += $export
        
        Start-Sleep -Milliseconds 200  # Rate limiting
    } catch {
        Write-Warning "Failed to process $convId : $($_.Exception.Message)"
    }
}

Write-Host "Processed $($results.Count) of $($conversationIds.Count) conversations"
```

### 4. Performance Optimization
- Use `-IncludeRawData` only when needed
- Filter timeline events in PowerShell rather than pulling additional data
- Consider pagination for large date ranges

## Troubleshooting

### ImportExcel Module Not Found

```powershell
# Install the module
Install-Module ImportExcel -Scope CurrentUser -Force

# Verify installation
Get-Module -ListAvailable ImportExcel
```

### API Permission Errors

Ensure your OAuth token has these scopes:
- `conversations:readonly`
- `analytics:readonly`
- `speechandtextanalytics:readonly`
- `recording:readonly`
- `telephony:readonly`

### Rate Limiting

Genesys Cloud has rate limits. If you encounter 429 errors:
```powershell
# Add retry logic
$maxRetries = 3
$retryCount = 0

do {
    try {
        $timeline = Get-GCConversationTimeline -BaseUri $baseUri -AccessToken $token -ConversationId $convId
        break
    } catch {
        $retryCount++
        if ($retryCount -ge $maxRetries) { throw }
        Write-Warning "Rate limited, waiting 5 seconds (retry $retryCount/$maxRetries)..."
        Start-Sleep -Seconds 5
    }
} while ($retryCount -lt $maxRetries)
```

## Architecture

### Module Structure
```
GenesysCloud.ConversationToolkit/
├── GenesysCloud.ConversationToolkit.psd1  # Module manifest
└── GenesysCloud.ConversationToolkit.psm1  # Module implementation
```

### Internal Components
- **Invoke-GCRequest** - Centralized HTTP request wrapper (module-level helper)
- **Add-TimelineEvent** - Timeline event normalization (private helper)
- **6 Exported Functions** - Public API

### Data Flow
```
Genesys Cloud APIs
    ↓
Invoke-GCRequest (HTTP wrapper)
    ↓
Get-GCConversationTimeline (aggregation)
    ↓
TimelineEvents (normalized data)
    ↓
Export-GCConversationToExcel (formatting)
    ↓
Professional Excel Report
```

## Version History

### v0.1.0 (Current)
- Initial release
- Consolidated Invoke-GCRequest to single module-level function
- Added Export-GCConversationToExcel with professional formatting
- Validated conversation correlation logic
- Full multi-source timeline aggregation
- Support for MediaEndpointStats extraction
- WebRTC error tracking
- SIP message analysis

## Contributing

This module is part of the Genesys-API-Explorer project. Contributions welcome!

## License

Copyright (c) Internal use. All rights reserved.

## Support

For issues or questions, please refer to the main Genesys-API-Explorer documentation.
