# Genesys Cloud API Explorer (WPF PowerShell GUI)

PowerShell-based WPF application that mirrors the Genesys Cloud API catalog, provides transparency-first logging, and lets you inspect/save large responses, track job endpoints, and reuse favorite payloads.

---

## Features

### Core Capabilities
- WPF shell with OAuth token field, Help menu, splash screen, grouped path/method selection, jobs watcher tab, schema viewer, inspector, and favorites panel
- Dynamically generated parameter editors (query/path/body/header) with required-field hints and schema preview powered by the Genesys OpenAPI definitions
- Dispatches requests with `Invoke-WebRequest`, logs every request/response, and formats big JSON results in the inspector/export dialogs
- Job Watch tab polls `/jobs` endpoints until they complete, downloads results to temp files, and exposes export/copy hooks so the UI never freezes on large payloads
- **Conversation Report tab** merges real-time conversation details with analytics data into a unified report, with export options for JSON and human-readable text formats
- Favorites persist under `%USERPROFILE%\GenesysApiExplorerFavorites.json` and capture endpoint + payload details for reuse
- Inspector lets you explore large responses via tree view, raw text, clipboard/export, and warns before parsing huge files

### Phase 1 Enhancements (New!)
- **Enhanced Token Management**: Test Token button to instantly verify OAuth token validity with clear status indicators (✓ Valid, ✗ Invalid, ⚠ Unknown)
- **Request History**: Automatically tracks the last 50 API requests with timestamp, method, path, status, and duration. Easily replay previous requests with one click
- **Progress Indicators**: Visual progress indicator (⏳) during API calls with elapsed time tracking and responsive UI
- **Enhanced Response Viewer**: Toggle between raw and formatted JSON views, with improved response display
- **Detailed Error Display**: Comprehensive error information including HTTP status codes, headers, and response body for better troubleshooting

---

## Requirements

- Windows PowerShell 5.1+ (with WPF libraries available). PowerShell Core is supported only on Windows hosts that expose the PresentationFramework assembly.
- Valid Genesys Cloud OAuth token (paste into the UI before submitting calls).
- API catalog JSON exported from [Genesys Cloud API Explorer](https://developer.genesys.cloud/developer-tools/#/api-explorer).
- Internet access to reach `https://api.mypurecloud.com` and the documentation hubs (`https://developer.genesys.cloud`, `https://help.mypurecloud.com`).

---

## Project Structure

```plaintext
Genesys-API-Explorer/
├── GenesysCloudAPIExplorer.ps1           # Main GUI script
├── GenesysCloudAPIEndpoints.json         # API endpoint catalog exported from Genesys Cloud
├── README.md                             # This documentation
└── .github/
    └── workflows/
        └── test.yml                      # GitHub Actions workflow for testing
```

---

## Usage

1. Run the script using Windows PowerShell:
   ```powershell
   .\GenesysCloudAPIExplorer.ps1
   ```
2. When prompted, paste your Genesys Cloud OAuth token into the token field
3. Click "Test Token" to verify your token is valid
4. Select an API group, endpoint path, and HTTP method from the dropdowns
5. Fill in any required parameters and click "Submit API Call"
6. View responses in the Response tab and use the Inspector for large results

### Token Management

The enhanced token management feature helps ensure your OAuth token is valid before making API calls:

- **Test Token Button**: Click to instantly verify your token validity
- **Status Indicator**: Shows token status with clear visual feedback:
  - ✓ Valid (green) - Token is valid and ready to use
  - ✗ Invalid (red) - Token is invalid or expired
  - ⚠ Unknown (orange) - Unable to determine token status
  - Not tested (gray) - Token hasn't been tested yet

### Request History

The **Request History** tab automatically tracks your API requests:

1. Navigate to the "Request History" tab to view recent requests
2. Each entry shows: timestamp, method, path, status code, and duration
3. Select any request and click "Replay Request" to load it back into the main form
4. Click "Clear History" to remove all tracked requests
5. History is limited to the last 50 requests for performance

### Response Viewer

Enhanced response viewing capabilities:

- **Toggle Raw/Formatted**: Switch between formatted JSON and raw response text
- **Response Inspector**: Click "Inspect Result" to explore large responses in a tree view
- **Progress Indicator**: Visual feedback during API calls with elapsed time display

### Conversation Report

The **Conversation Report** tab allows you to generate comprehensive reports for individual conversations:

1. Navigate to the "Conversation Report" tab
2. Enter a conversation ID in the input field
3. Click "Run Report" to fetch both conversation details and analytics data
4. View the human-readable report in the text area
5. Use "Inspect Result" to view the merged JSON data in the tree inspector
6. Export results as JSON or text files using the export buttons

#### Report Sections

The conversation report includes the following insight-focused sections:

- **Key Insights** - Quick takeaways including overall quality rating, quality issues, timing anomalies, and actionable observations
- **Duration Analysis** - Breakdown of time spent in IVR, queue, hold, talk, and wrap-up phases with human-readable durations
- **Conversation Flow Path** - Visual representation of the call path through IVR, queues, and agents showing transfers
- **Participant Statistics** - Per-participant metrics including time in conversation, MOS quality scores, session counts, and disconnect information
- **Chronological Timeline** - Detailed event-by-event timeline with timestamps, participants, and segment information
- **Summary** - Statistics on segments, degraded quality segments (MOS < 3.5), and disconnect events

The report is designed to provide actionable insights at a glance, with the most important information (Key Insights) appearing first.

---

## Testing

GitHub Actions automatically runs syntax validation and function tests on push and pull requests. To run tests locally:

```powershell
# Parse the script to check for syntax errors
$tokens = $null
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    ".\GenesysCloudAPIExplorer.ps1",
    [ref]$tokens,
    [ref]$errors
)
if ($errors) { $errors | ForEach-Object { Write-Error $_ } }
```
