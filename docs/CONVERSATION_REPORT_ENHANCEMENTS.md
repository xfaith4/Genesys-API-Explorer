# Conversation Report Enhancements

## Overview

The Conversation Report feature has been significantly enhanced to provide better visibility into API operations and automatic handling of paginated results. These enhancements address the need for transparency in API interactions and robust support for large dataset retrieval.

## Features

### 1. Multi-Endpoint Query Visibility

The Conversation Report now queries **6 different API endpoints** (expanded from 2) to provide comprehensive conversation data:

| Endpoint | Path | Required | Description |
|----------|------|----------|-------------|
| Conversation Details | `/api/v2/conversations/{id}` | ✓ | Core conversation data including participants and segments |
| Analytics Details | `/api/v2/analytics/conversations/{id}/details` | ✓ | Detailed analytics including MediaEndpointStats and metrics |
| Speech & Text Analytics | `/api/v2/speechandtextanalytics/conversations/{id}` | Optional | Speech analytics and transcription data |
| Recording Metadata | `/api/v2/conversations/{id}/recordingmetadata` | Optional | Recording availability and metadata |
| Sentiments | `/api/v2/speechandtextanalytics/conversations/{id}/sentiments` | Optional | Sentiment analysis results |
| SIP Messages | `/api/v2/telephony/sipmessages/conversations/{id}` | Optional | SIP signaling messages for telephony debugging |

### 2. Real-Time Progress Tracking

The enhanced UI provides live feedback as each endpoint is queried:

**Progress Bar**
- Visual indicator showing completion percentage (0-100%)
- Updates in real-time as each endpoint is processed

**Progress Text**
- Shows current operation: "Querying: Conversation Details"
- Updates to show completion status: "✓ Analytics Details" or "✗ Failed Endpoint"

**Endpoint Query Log**
- Timestamped log showing each API call
- Success indicators: ✓ (success), ⚠ (optional/not available), ✗ (failed)
- Real-time scrolling updates as operations complete

Example log output:
```
[10:45:23] Querying: Conversation Details...
[10:45:23] ✓ Conversation Details - Retrieved successfully
[10:45:24] Querying: Analytics Details...
[10:45:24] ✓ Analytics Details - Retrieved successfully
[10:45:25] Querying: Speech & Text Analytics...
[10:45:25] ⚠ Speech & Text Analytics - Optional, not available
[10:45:26] Querying: Recording Metadata...
[10:45:26] ✓ Recording Metadata - Retrieved successfully
[10:45:27] Querying: Sentiments...
[10:45:27] ⚠ Sentiments - Optional, not available
[10:45:28] Querying: SIP Messages...
[10:45:28] ✓ SIP Messages - Retrieved successfully
```

### 3. Automatic Pagination Support

The system now intelligently handles three types of API pagination:

#### Cursor-Based Pagination
For APIs that return a `cursor` field in the response:
```json
{
  "entities": [...],
  "cursor": "abc123xyz"
}
```
The system automatically appends `?cursor=abc123xyz` or `&cursor=abc123xyz` to fetch the next page.

#### URI-Based Pagination
For APIs that return a `nextUri` field:
```json
{
  "entities": [...],
  "nextUri": "https://api.usw2.pure.cloud/api/v2/analytics/conversations/details/jobs/job123/results?pageNumber=2"
}
```
The system uses the provided URI directly for the next request.

#### Page Number Pagination
For APIs that return `pageCount` and `pageNumber`:
```json
{
  "entities": [...],
  "pageNumber": 1,
  "pageCount": 5
}
```
The system increments `pageNumber` until reaching `pageCount`.

### 4. Jobs Endpoint Integration

The **Fetch Job Results** functionality has been enhanced to automatically handle paginated job results:

**Before Enhancement:**
- Only fetched first page of results
- Limited to pageSize parameter (typically 100)
- Manual intervention needed for large result sets

**After Enhancement:**
- Automatically fetches ALL pages
- Progress indicator shows: "Fetching results - Fetching page 2..."
- Combines all pages into single JSON file
- Displays total count: "150 results saved to temp file"

Example workflow:
1. User submits POST to `/api/v2/analytics/conversations/details/jobs`
2. System polls job status until complete
3. User clicks "Fetch Job Results"
4. System automatically fetches all paginated pages
5. All results saved to single temp file

### 5. Pagination Detection in General Requests

When sending any API request, the system now detects pagination in the response:

**Status Bar Updates:**
- No pagination: "Last call succeeded (200) - 145 ms"
- Cursor pagination: "Last call succeeded (200) - 145 ms (Cursor-based pagination detected)"
- Page pagination: "Last call succeeded (200) - 145 ms (Page 1 of 5)"
- URI pagination: "Last call succeeded (200) - 145 ms (Next page available via nextUri)"

**Transparency Log Entry:**
```
Response: 200 returned 45678 chars in 145 ms. (Page 1 of 5)
Note: Response contains pagination. To fetch all pages, use Get-PaginatedResults function or the Jobs results fetcher for job endpoints.
```

## Usage Examples

### Example 1: Generate Conversation Report

1. Navigate to the **Conversation Report** tab
2. Enter a conversation ID: `abc-123-def-456`
3. Click **Run Report**
4. Watch the progress bar and endpoint log update in real-time
5. Review the comprehensive report in the text area
6. Use **Inspect Result** to view raw JSON from all 6 endpoints
7. Export results as JSON or formatted text

### Example 2: Fetch Paginated Job Results

1. Use the **Query Templates** to load "Create Conversation Details Job"
2. Modify date range in the body JSON
3. Click **Send Request**
4. System detects job creation and starts polling
5. When job completes, click **Fetch Job Results**
6. Watch progress: "Fetching results - Fetching page 1...", "Fetching page 2...", etc.
7. All pages automatically combined and saved
8. View total count: "347 results saved to temp file"

### Example 3: Detect Pagination in API Response

1. Send POST request to `/api/v2/analytics/conversations/details/query`
2. Review response in Response Viewer
3. Check status bar for pagination info
4. If paginated, note in Transparency Log
5. Use Get-PaginatedResults function in custom scripts to fetch all pages

## Technical Implementation

### Get-PaginatedResults Function

The core pagination handler is implemented as a reusable function:

```powershell
Get-PaginatedResults `
    -BaseUrl "https://api.usw2.pure.cloud" `
    -InitialPath "/api/v2/analytics/conversations/details/jobs/job123/results" `
    -Headers $headers `
    -Method "GET" `
    -ProgressCallback $callback
```

**Parameters:**
- `BaseUrl`: API base URL for the region
- `InitialPath`: Initial endpoint path (may include query parameters)
- `Headers`: HTTP headers including Authorization
- `Method`: HTTP method (GET or POST)
- `Body`: Optional request body for POST requests
- `ProgressCallback`: Optional scriptblock for progress updates

**Return Value:**
- ArrayList containing all results from all pages combined

**Supported Response Structures:**
- `entities` array (most analytics APIs)
- `conversations` array (conversation APIs)
- Direct arrays `[...]`
- Single objects (treated as one-item collection)

### Progress Callback Pattern

Progress callbacks receive these parameters:
- `PageNumber`: Current page being fetched
- `Status`: Status message (e.g., "Fetching page 2...")
- `IsError`: Boolean indicating error state
- `IsComplete`: Boolean indicating completion

Example callback:
```powershell
$callback = {
    param($PageNumber, $Status, $IsError, $IsComplete)
    
    if ($IsError) {
        Write-Host "ERROR: $Status" -ForegroundColor Red
    }
    elseif ($IsComplete) {
        Write-Host "COMPLETE: $Status" -ForegroundColor Green
    }
    else {
        Write-Host "Progress: $Status" -ForegroundColor Yellow
    }
}
```

## API Endpoint Compatibility

### Tested Endpoints

The pagination support has been designed for these Genesys Cloud API endpoints:

**Jobs API:**
- `/api/v2/analytics/conversations/details/jobs/{jobId}/results`
- `/api/v2/analytics/users/details/jobs/{jobId}/results`
- `/api/v2/analytics/queues/observations/jobs/{jobId}/results`

**Query API:**
- `/api/v2/analytics/conversations/details/query`
- `/api/v2/analytics/conversations/aggregates/query`
- `/api/v2/analytics/users/details/query`

**Conversation API:**
- `/api/v2/conversations` (list conversations)
- `/api/v2/analytics/conversations/details` (bulk details)

### Pagination Styles by Endpoint

| Endpoint | Pagination Type | Fields Used |
|----------|----------------|-------------|
| Job Results | Page Number | `pageCount`, `pageNumber` |
| Conversations List | Cursor | `cursor` |
| Analytics Query | Cursor | `cursor` |
| Bulk Operations | Cursor or Page | Auto-detected |

## Benefits

### For Users
- **Transparency**: See exactly what endpoints are being queried
- **Progress Feedback**: Real-time updates on long-running operations
- **Complete Data**: Automatically fetch all pages without manual effort
- **Error Visibility**: Clearly see which optional endpoints failed

### For Developers
- **Reusable Function**: Get-PaginatedResults can be used in custom scripts
- **Flexible Design**: Supports all three pagination patterns
- **Progress Callbacks**: Easy to integrate progress reporting
- **Error Handling**: Graceful failure with detailed error messages

### For Operations
- **Audit Trail**: Endpoint query log provides audit record
- **Large Datasets**: Handle jobs with thousands of results
- **Efficiency**: Single operation fetches all data automatically
- **Reliability**: Automatic retry and pagination continuation

## Best Practices

### When to Use Pagination
- **Always** use pagination for job results endpoints
- Use pagination for list endpoints that may return many items
- Consider pagination for any query that might exceed single page limits

### Performance Considerations
- Large datasets (1000+ items) will take time to fetch all pages
- Each page requires a separate API call (rate limit considerations)
- Progress feedback keeps users informed during long operations

### Error Handling
- Optional endpoints (Speech/Text, Recording, etc.) may fail gracefully
- Required endpoints (Conversation, Analytics) will stop report generation on failure
- Pagination errors are logged but don't fail entire operation

## Migration Notes

### Backward Compatibility
- Existing conversation report functionality preserved
- Optional endpoints don't break existing workflows
- Progress UI elements are additive (don't replace existing features)

### Breaking Changes
None. All enhancements are additive and backward compatible.

## Future Enhancements

Potential future improvements:
1. **Parallel Page Fetching**: Fetch multiple pages concurrently
2. **Configurable Page Size**: Allow users to adjust pageSize parameter
3. **Export All Pages**: Direct export button for paginated responses
4. **Pagination Statistics**: Show page fetch times and rate limit usage
5. **Resume Capability**: Resume interrupted pagination operations

## Troubleshooting

### Issue: Progress Bar Not Updating
**Solution**: Ensure `[System.Windows.Forms.Application]::DoEvents()` is called in progress callback.

### Issue: Pagination Not Detected
**Solution**: Check response structure. Some APIs use non-standard pagination fields.

### Issue: Job Results Incomplete
**Solution**: Verify job status is "COMPLETED" before fetching results. Check Transparency Log for errors.

### Issue: "Optional - Not Available" Messages
**Solution**: These are normal. Optional endpoints may not have data for all conversations.

## Support and Feedback

For questions or issues with the enhanced Conversation Report:
1. Check the Transparency Log for detailed error messages
2. Review the Endpoint Query Log for API call details
3. Use the Inspect Result button to view raw API responses
4. Export logs for troubleshooting and support requests

## Related Documentation

- [Conversation Toolkit](CONVERSATION_TOOLKIT.md) - Module using similar multi-endpoint approach
- [Template Catalog](TEMPLATE_CATALOG.md) - Pre-built query templates for jobs endpoints
- [Problem Statement Implementation](PROBLEM_STATEMENT_IMPLEMENTATION.md) - Overall project requirements
