# Genesys Cloud Reporting Functions

This document describes the comprehensive reporting capabilities available in the GenesysCloud.OpsInsights module for analyzing conversation data, queue performance, division metrics, and routing status tracking.

---

## Overview

The reporting functions provide three primary lenses for analyzing Genesys Cloud operations:

1. **Queue-Level Analysis** - `Get-GCQueueSmokeReport`
2. **Division-Level Analysis** - `Get-GCDivisionReport`
3. **Routing Status Tracking** - `Get-GCRoutingStatusReport`

All reporting functions calculate key operational metrics including abandon rates, error rates, and average handling times.

---

## Get-GCQueueSmokeReport

Produces a "smoke detector" report for queues and agents using conversation aggregate metrics.

### Features

- Queries `/api/v2/analytics/conversations/aggregates/query` grouped by queueId and userId
- Calculates abandon rate: `nAbandoned / nOffered * 100`
- Calculates error rate: `nError / nOffered * 100`
- Computes average handle, talk, and wait times
- Returns top N queues/agents by failure indicators

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `BaseUri` | string | No | Region base URI (uses Connect-GCCloud context if not specified) |
| `AccessToken` | string | No | OAuth Bearer token (uses Connect-GCCloud context if not specified) |
| `Interval` | string | **Yes** | Analytics interval (e.g., `2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z`) |
| `DivisionId` | string | No | Optional division filter |
| `QueueIds` | string[] | No | Optional list of queueIds to restrict the query |
| `TopN` | int | No | Number of top queues/agents to surface (default: 10) |

### Return Object

```powershell
@{
    Interval     = "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z"
    QueueSummary = @(
        # Array of queue metrics
        @{
            QueueId      = "queue-id-123"
            Offered      = 1500
            Answered     = 1350
            Abandoned    = 150
            Errors       = 10
            AbandonRate  = 10.00
            ErrorRate    = 0.67
            AvgHandle    = 245.50  # seconds
            AvgTalk      = 180.25  # seconds
            AvgWait      = 45.00   # seconds
        }
    )
    QueueTop     = @(# Top N queues sorted by AbandonRate, ErrorRate, Offered)
    AgentSummary = @(# Array of agent metrics)
    AgentTop     = @(# Top N agents sorted by failure indicators)
}
```

### Example Usage

```powershell
# Import the module
Import-Module ./src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1

# Connect to Genesys Cloud
Connect-GCCloud -RegionDomain 'usw2.pure.cloud' -AccessToken $token

# Generate queue smoke report for the last 7 days
$report = Get-GCQueueSmokeReport -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' -TopN 5

# View top 5 problematic queues
$report.QueueTop | Format-Table QueueId, Offered, AbandonRate, ErrorRate

# Filter to specific queues
$queueIds = @('queue-1', 'queue-2', 'queue-3')
$report = Get-GCQueueSmokeReport -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' -QueueIds $queueIds

# Export to CSV for analysis
$report.QueueSummary | Export-Csv -Path "QueueMetrics.csv" -NoTypeInformation
```

---

## Get-GCDivisionReport

Produces division-level conversation aggregation reports with abandon rates and key performance metrics.

### Features

- Queries `/api/v2/analytics/conversations/aggregates/query` grouped by divisionId
- Calculates abandon rate: `nAbandoned / nOffered * 100`
- Calculates error rate: `nError / nOffered * 100`
- Supports optional queue and media type filtering
- Returns top N divisions by failure indicators

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `BaseUri` | string | No | Region base URI (uses Connect-GCCloud context if not specified) |
| `AccessToken` | string | No | OAuth Bearer token (uses Connect-GCCloud context if not specified) |
| `Interval` | string | **Yes** | Analytics interval (e.g., `2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z`) |
| `QueueIds` | string[] | No | Optional list of queueIds to restrict the query |
| `MediaType` | string | No | Optional media type filter: 'voice', 'chat', 'email', 'callback', 'message' |
| `TopN` | int | No | Number of top divisions to surface (default: 10) |

### Return Object

```powershell
@{
    Interval        = "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z"
    DivisionSummary = @(
        # Array of division metrics
        @{
            DivisionId   = "division-id-456"
            Offered      = 5000
            Answered     = 4500
            Abandoned    = 500
            Errors       = 25
            AbandonRate  = 10.00
            ErrorRate    = 0.50
            AvgHandle    = 300.75  # seconds
            AvgTalk      = 220.50  # seconds
            AvgWait      = 60.25   # seconds
        }
    )
    DivisionTop     = @(# Top N divisions sorted by AbandonRate, ErrorRate, Offered)
}
```

### Example Usage

```powershell
# Generate division report for voice calls in the last 30 days
$report = Get-GCDivisionReport `
    -Interval '2025-11-08T00:00:00.000Z/2025-12-08T23:59:59.999Z' `
    -MediaType 'voice' `
    -TopN 5

# View all divisions
$report.DivisionSummary | Format-Table DivisionId, Offered, Answered, AbandonRate, ErrorRate

# View top 5 divisions with highest abandon rates
$report.DivisionTop | Format-Table DivisionId, AbandonRate, ErrorRate, Offered

# Filter to specific queues within divisions
$queueIds = @('queue-1', 'queue-2')
$report = Get-GCDivisionReport `
    -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' `
    -QueueIds $queueIds

# Export to JSON for further analysis
$report | ConvertTo-Json -Depth 10 | Out-File "DivisionReport.json"
```

---

## Get-GCRoutingStatusReport

Produces routing status duration reports from conversation details, tracking time spent in each routing status including "Not Responding".

### Features

- Queries `/api/v2/analytics/conversations/details/query` to fetch segment-level data
- Extracts and aggregates routing status durations from conversation segments
- Supports grouping by queue, division, agent, or overall
- Calculates total duration, segment count, and average duration per routing status
- Handles pagination automatically (configurable max pages)

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `BaseUri` | string | No | Region base URI (uses Connect-GCCloud context if not specified) |
| `AccessToken` | string | No | OAuth Bearer token (uses Connect-GCCloud context if not specified) |
| `Interval` | string | **Yes** | Analytics interval (e.g., `2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z`) |
| `GroupBy` | string | No | Dimension to group results: 'queue', 'division', 'agent', or 'none' (default: 'none') |
| `QueueIds` | string[] | No | Optional list of queueIds to restrict the query |
| `DivisionId` | string | No | Optional division filter |
| `PageSize` | int | No | Conversations per page (default: 100, max: 100) |
| `MaxPages` | int | No | Maximum pages to retrieve (default: 10 to prevent runaway queries) |

### Return Object

```powershell
@{
    Interval             = "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z"
    GroupBy              = "queue"
    TotalConversations   = 150
    RoutingStatusSummary = @(
        # Array of routing status metrics across all groups
        @{
            GroupKey         = "queue-id-123"
            RoutingStatus    = "NOT_RESPONDING"
            SegmentCount     = 25
            TotalDurationSec = 1250.50
            AvgDurationSec   = 50.02
        },
        @{
            GroupKey         = "queue-id-123"
            RoutingStatus    = "IDLE"
            SegmentCount     = 100
            TotalDurationSec = 5000.75
            AvgDurationSec   = 50.01
        }
    )
    GroupedByQueue       = @{
        # Hashtable of queue-specific results (when GroupBy = 'queue')
        "queue-id-123" = @(
            # Array of routing status metrics for this queue
        )
    }
}
```

### Example Usage

```powershell
# Track routing status durations grouped by queue
$report = Get-GCRoutingStatusReport `
    -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' `
    -GroupBy 'queue'

# View "Not Responding" status across all queues
$report.RoutingStatusSummary | 
    Where-Object { $_.RoutingStatus -eq 'NOT_RESPONDING' } | 
    Format-Table GroupKey, SegmentCount, TotalDurationSec, AvgDurationSec

# Track routing status by division
$report = Get-GCRoutingStatusReport `
    -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' `
    -GroupBy 'division' `
    -DivisionId 'division-123'

# Track by agent with specific queues
$report = Get-GCRoutingStatusReport `
    -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' `
    -GroupBy 'agent' `
    -QueueIds @('queue-1', 'queue-2')

# Overall routing status summary
$report = Get-GCRoutingStatusReport `
    -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z' `
    -GroupBy 'none'

# Export routing status data
$report.RoutingStatusSummary | Export-Csv -Path "RoutingStatus.csv" -NoTypeInformation
```

---

## Combined Reporting Workflow

Example workflow combining multiple reporting functions for comprehensive analysis:

```powershell
# 1. Connect to Genesys Cloud
Connect-GCCloud -RegionDomain 'usw2.pure.cloud' -AccessToken $token

# 2. Define reporting interval
$interval = '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z'

# 3. Get division-level metrics
$divisionReport = Get-GCDivisionReport -Interval $interval -TopN 5
Write-Host "Top 5 Divisions by Abandon Rate:"
$divisionReport.DivisionTop | Format-Table DivisionId, AbandonRate, Offered

# 4. Get queue-level metrics
$queueReport = Get-GCQueueSmokeReport -Interval $interval -TopN 10
Write-Host "Top 10 Queues with Issues:"
$queueReport.QueueTop | Format-Table QueueId, AbandonRate, ErrorRate

# 5. Track routing status durations by queue
$statusReport = Get-GCRoutingStatusReport -Interval $interval -GroupBy 'queue'
Write-Host "Not Responding Status by Queue:"
$statusReport.RoutingStatusSummary | 
    Where-Object { $_.RoutingStatus -eq 'NOT_RESPONDING' } | 
    Format-Table GroupKey, SegmentCount, TotalDurationSec

# 6. Export all reports for further analysis
$divisionReport | ConvertTo-Json -Depth 10 | Out-File "Reports_Division.json"
$queueReport | ConvertTo-Json -Depth 10 | Out-File "Reports_Queue.json"
$statusReport | ConvertTo-Json -Depth 10 | Out-File "Reports_RoutingStatus.json"

Write-Host "All reports generated successfully!"
```

---

## Metrics Glossary

### Common Metrics

- **Offered**: Total number of interactions offered to the queue/division/agent
- **Answered**: Total number of interactions answered
- **Abandoned**: Total number of interactions abandoned by the customer
- **Errors**: Total number of interactions with errors
- **AbandonRate**: Percentage of offered interactions that were abandoned (`nAbandoned / nOffered * 100`)
- **ErrorRate**: Percentage of offered interactions with errors (`nError / nOffered * 100`)
- **AvgHandle**: Average handle time in seconds (total handle time / answered)
- **AvgTalk**: Average talk time in seconds (total talk time / answered)
- **AvgWait**: Average wait time in seconds (total wait time / offered)

### Routing Status Metrics

- **RoutingStatus**: The routing status of the agent (e.g., "NOT_RESPONDING", "IDLE", "INTERACTING", "COMMUNICATING")
- **SegmentCount**: Number of conversation segments with this routing status
- **TotalDurationSec**: Total time spent in this routing status (seconds)
- **AvgDurationSec**: Average duration per segment in this routing status (seconds)

### Common Routing Statuses

- **NOT_RESPONDING**: Agent did not respond to an interaction within the configured timeout
- **IDLE**: Agent is available and ready for interactions
- **INTERACTING**: Agent is currently interacting with a customer
- **COMMUNICATING**: Agent is communicating (usually on a call)
- **OFF_QUEUE**: Agent is off queue and not available for routing

---

## Best Practices

### Interval Selection

- Use reasonable intervals to avoid overwhelming the API
- For high-volume environments, start with 1-day intervals
- For historical analysis, use weekly or monthly intervals
- Consider peak hours when analyzing specific time periods

### Pagination

- `Get-GCRoutingStatusReport` uses pagination with default `MaxPages=10`
- Each page can retrieve up to 100 conversations (`PageSize=100`)
- Adjust `MaxPages` based on your data volume and analysis needs
- Monitor total conversation count in results to ensure complete coverage

### Performance Optimization

1. **Use specific filters**: Apply `QueueIds`, `DivisionId`, or `MediaType` filters to reduce data volume
2. **Start with aggregates**: Use `Get-GCQueueSmokeReport` and `Get-GCDivisionReport` before drilling into conversation details
3. **Limit TopN**: Use smaller TopN values for faster results
4. **Cache results**: Store report outputs and reuse for multiple analyses

### Abandon Rate Analysis

- Abandon rates > 5% typically indicate queue staffing issues
- Compare abandon rates across divisions to identify problem areas
- Correlate high abandon rates with average wait times
- Track trends over time to measure improvement

### Routing Status Monitoring

- Track "NOT_RESPONDING" status to identify agent responsiveness issues
- Monitor average duration in each status for workload analysis
- Compare routing status patterns across queues and divisions
- Use agent-level grouping to identify individual performance issues

---

## Troubleshooting

### Common Issues

**Issue**: "Resolve-GCAuth" error when running reports

**Solution**: Ensure you've called `Connect-GCCloud` first or provide explicit `-BaseUri` and `-AccessToken` parameters

```powershell
# Option 1: Use connection context
Connect-GCCloud -RegionDomain 'usw2.pure.cloud' -AccessToken $token
Get-GCQueueSmokeReport -Interval $interval

# Option 2: Explicit parameters
Get-GCQueueSmokeReport -BaseUri 'https://api.usw2.pure.cloud' -AccessToken $token -Interval $interval
```

**Issue**: Empty or missing results

**Solution**: Verify your interval is correct and contains data. Check that filters aren't too restrictive.

```powershell
# Test with a broader interval first
$report = Get-GCDivisionReport -Interval '2025-01-01T00:00:00.000Z/2025-12-31T23:59:59.999Z'
$report.DivisionSummary.Count  # Should show number of divisions found
```

**Issue**: Routing status report returns no data

**Solution**: Ensure conversations exist in the interval and that agent segments contain routing status properties. Not all conversation types track routing status.

---

## See Also

- [GenesysCloud.OpsInsights Module Documentation](../src/GenesysCloud.OpsInsights/README.md)
- [Conversation Toolkit Documentation](CONVERSATION_TOOLKIT.md)
- [Genesys Cloud Analytics API Documentation](https://developer.genesys.cloud/devapps/api-explorer)
