# Genesys Cloud API Explorer (WPF PowerShell GUI)

PowerShell-based WPF application that mirrors the Genesys Cloud API catalog, provides transparency-first logging, and lets you inspect/save large responses, track job endpoints, and reuse favorite payloads.

---

## Features

### GenesysCloud.ConversationToolkit

**A central feature of the Genesys-API-Explorer**, the ConversationToolkit is a comprehensive PowerShell module for Genesys Cloud engineers to:

- **Analyze conversation details** from multiple API sources (Core, Analytics, Speech, Recording, SIP, Sentiment)
- **Extract MediaEndpointStats** for quality analysis (MOS scores, packet loss, jitter)
- **Identify WebRTC errors** and telephony issues
- **Track routing problems** across queues and transfers
- **Generate professional Excel reports** with TableStyle Light11, AutoFilter, and AutoSize
- **Correlate all data via ConversationId** in chronological timelines

**Key Functions:**

- `Get-GCConversationTimeline` - Aggregate data from 6 API endpoints into unified timeline
- `Export-GCConversationToExcel` - Professional Excel reports with elegant formatting
- `Get-GCQueueSmokeReport` - Queue performance and error rate analysis
- `Get-GCQueueHotConversations` - Identify problematic conversations
- `Show-GCConversationTimelineUI` - Interactive WPF timeline viewer
- `Invoke-GCSmokeDrill` - End-to-end investigation workflow

**Quick Start:**

```powershell
# Import the toolkit
Import-Module ./Scripts/GenesysCloud.ConversationToolkit/GenesysCloud.ConversationToolkit.psd1

# Pull conversation timeline from all sources
$timeline = Get-GCConversationTimeline `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -AccessToken $token `
    -ConversationId $convId

# Export to professionally formatted Excel
Export-GCConversationToExcel `
    -ConversationData $timeline `
    -OutputPath "Report.xlsx" `
    -IncludeRawData
```

📖 **[Complete Conversation Toolkit Documentation](docs/CONVERSATION_TOOLKIT.md)**

---

### Core Capabilities

- WPF shell with OAuth token field, Help menu, splash screen, grouped path/method selection, jobs watcher tab, schema viewer, inspector, and favorites panel
- Dynamically generated parameter editors (query/path/body/header) with required-field hints and schema preview powered by the Genesys OpenAPI definitions
- Dispatches requests via the core module's `Invoke-GCRequest` helper, logs every request/response, and formats big JSON results in the inspector/export dialogs
- Job Watch tab polls `/jobs` endpoints until they complete, downloads results to temp files, and exposes export/copy hooks so the UI never freezes on large payloads
- **Conversation Report tab** queries 6 API endpoints with real-time progress tracking, automatic pagination support, and comprehensive visibility into conversation data. Features include:
  - Progress bar and timestamped endpoint query log
  - 6-endpoint coverage: Conversation Details, Analytics, Speech/Text Analytics, Recording Metadata, Sentiments, SIP Messages
  - Automatic pagination detection and handling for jobs endpoints
  - Export options for JSON and human-readable text formats
  - 📖 **[Complete Conversation Report Documentation](docs/CONVERSATION_REPORT_ENHANCEMENTS.md)**
- Favorites persist under `%USERPROFILE%\GenesysApiExplorerFavorites.json` and capture endpoint + payload details for reuse
- Inspector lets you explore large responses via tree view, raw text, clipboard/export, and warns before parsing huge files

### Insight Packs & Evidence Briefings

- The `insightpacks/` folder now defines curated workflows such as `gc.queues.smoke.v1` and `gc.dataActions.failures.v1`. Run any pack with:

  ```powershell
  $result = Invoke-GCInsightPack -PackPath .\insightpacks\gc.queues.smoke.v1.json -Parameters @{ startDate = '2025-12-01T00:00:00Z'; endDate = '2025-12-08T00:00:00Z' }
  ```

  Each result includes computed metrics, drilldowns, and an `Evidence` property containing narrative context.

- Use `Export-GCInsightBriefing -Result $result -Directory ./reports` to bundle the evidence packet into:
  - JSON snapshot (`.snapshot.json`)
  - HTML briefing (`.html`) via `Export-GCInsightPackHtml`
  - Excel/CSV table (`.xlsx`/`.csv`) via `Export-GCInsightPackExcel`

### Phase 1 Enhancements

- **Enhanced Token Management**: Test Token button to instantly verify OAuth token validity with clear status indicators (✓ Valid, ✗ Invalid, ⚠ Unknown)
- **Request History**: Automatically tracks the last 50 API requests with timestamp, method, path, status, and duration. Easily replay previous requests with one click
- **Progress Indicators**: Visual progress indicator (⏳) during API calls with elapsed time tracking and responsive UI
- **Enhanced Response Viewer**: Toggle between raw and formatted JSON views, with improved response display
- **Detailed Error Display**: Comprehensive error information including HTTP status codes, headers, and response body for better troubleshooting
- **Transparency Log Management**: Export transparency log to text file for auditing, clear log entries with confirmation dialog

### Phase 2 Enhancements

- **Type-Aware Parameter Controls**: Intelligent input controls that adapt based on parameter type
  - Dropdown (ComboBox) for enum parameters with predefined values
  - Checkbox for boolean parameters with visual default value indication
  - Multi-line text editor for JSON body parameters with real-time validation
  - **Array input fields** with comma-separated value support and type validation
- **Real-Time Validation**: Instant feedback on parameter values
  - Required field validation before submission with clear error messages
  - JSON syntax validation for body parameters with visual border feedback (green=valid, red=invalid)
  - **Numeric validation** for integer and number parameters with min/max range checking
  - **String format validation** for email, URL, and date formats
  - **Array validation** for comma-separated list parameters
  - **Pattern matching** for parameters with regex constraints
  - Inline validation error messages with ✗ indicator
  - Comprehensive validation summary dialog for all errors
- **Enhanced User Experience**:
  - Parameter descriptions shown as tooltips on all input types with range and format information
  - Required fields highlighted with light yellow background
  - Default values automatically populated for enum and boolean parameters
  - **Character count and line numbers** for JSON body parameters
  - **Inline validation hints** for array, numeric, and format-validated parameters

### Phase 3 Enhancements

- **PowerShell Script Generation**: Export ready-to-run PowerShell scripts
  - Generate complete PowerShell script with all parameters and authentication
  - Automatic handling of query, path, and body parameters
  - Save to file and copy to clipboard in one action
  - Includes error handling and response formatting

- **cURL Command Export**: Cross-platform command generation
  - Generate cURL commands compatible with Linux, macOS, and Windows
  - Properly escaped parameters and JSON bodies
  - Copy to clipboard for immediate use
  - Perfect for sharing with non-PowerShell users

- **Request Template Management**: Save and reuse API configurations
  - Save current request configuration as a named template
  - Templates include path, method, and all parameters
  - Load templates to instantly recreate requests
  - Template library with sortable list view
  - Import/export template collections as JSON files
  - Templates persist to `%USERPROFILE%\GenesysApiExplorerTemplates.json`
  - Delete unwanted templates with confirmation
  - Share templates with team members via JSON export

### Phase 4 Enhancements (New!)

- **Read-Only Mode**: Application now focuses exclusively on data retrieval and analysis
  - PUT, PATCH, and DELETE methods are filtered out and not available
  - Ensures the application cannot modify your Genesys Cloud organization
  - Only GET and POST methods are available for safe data querying

- **Expanded Template Library**: 31 pre-configured templates focused on conversation data analysis and system monitoring
  - **22 GET templates** for retrieving conversation data, speech analytics, routing info, and user status
  - **9 POST templates** for advanced analytics queries and aggregates
  - Templates cover conversations, analytics, speech & text analytics, telephony, routing, and user data
  - All templates are read-only and designed for data analysis and reporting

---

## Requirements

- Windows PowerShell 5.1+ (with WPF libraries available). PowerShell Core is supported only on Windows hosts that expose the PresentationFramework assembly.
- Valid Genesys Cloud OAuth token (paste into the UI before submitting calls).
- API catalog JSON exported from [Genesys Cloud API Explorer](https://developer.genesys.cloud/developer-tools/#/api-explorer).
- Internet access to reach `https://api.mypurecloud.com` and the documentation hubs (`https://developer.genesys.cloud`, `https://help.mypurecloud.com`).
- **ImportExcel PowerShell module** (required for ConversationToolkit Excel export):

  ```powershell
  Install-Module ImportExcel -Scope CurrentUser -Force
  ```

---

## Project Structure

```plaintext
Genesys-API-Explorer/
├── GenesysCloudAPIExplorer.ps1                 # Entry stub that loads the OpsConsole module
├── apps/
│   └── OpsConsole/
│       ├── OpsConsole.psd1                      # Module manifest defining Start-GCOpsConsole
│       ├── OpsConsole.psm1                      # Module implementation
│       └── Resources/
│           ├── GenesysCloudAPIExplorer.ps1      # WPF GUI implementation executed by the module
│           ├── GenesysCloudAPIEndpoints.json     # API endpoint catalog
│           ├── DefaultTemplates.json             # Pre-configured POST conversation templates
│           └── ExamplePostBodies.json            # Example request bodies for common endpoints
├── README.md                                   # This documentation
├── Scripts/                                    # PowerShell scripts and modules
│   └── GenesysCloud.ConversationToolkit/       # Conversation analytics module (CENTRAL FEATURE)
│       ├── GenesysCloud.ConversationToolkit.psd1  # Module manifest
│       └── GenesysCloud.ConversationToolkit.psm1  # Module implementation
├── docs/                                       # Documentation directory
│   ├── CONVERSATION_TOOLKIT.md                 # Complete Conversation Toolkit reference
│   ├── DEVELOPMENT_HISTORY.md                  # Complete development timeline and feature history
│   ├── PROJECT_PLAN.md                         # 8-phase enhancement plan
│   ├── TEMPLATE_CATALOG.md                     # Complete reference of all 31 templates
│   ├── PHASE1_SUMMARY.md                       # Phase 1 implementation details
│   ├── PHASE2_SUMMARY.md                       # Phase 2 implementation details
│   ├── PHASE2_DEFERRED_SUMMARY.md              # Phase 2 extended features
│   ├── PHASE3_SUMMARY.md                       # Phase 3 implementation details
│   ├── PHASE4_SUMMARY.md                       # Phase 4 implementation details
│   ├── POST_CONVERSATIONS_TEMPLATES.md         # Template documentation
│   └── AI_RECREATION_PROMPT.md                 # Project context for AI assistants
└── .github/
    └── workflows/
        └── test.yml                            # GitHub Actions workflow for testing
```

---

## Usage

1. Run the script using Windows PowerShell (the stub now loads `apps/OpsConsole/OpsConsole.psd1` and calls `Start-GCOpsConsole`):

   ```powershell
   .\GenesysCloudAPIExplorer.ps1
   ```

2. (Optional) Import the OpsConsole module directly and call `Start-GCOpsConsole` if you want to embed the UI within another workflow:

   ```powershell
   Import-Module .\apps\OpsConsole\OpsConsole.psd1
   Start-GCOpsConsole
   ```

3. When prompted, paste your Genesys Cloud OAuth token into the token field
4. Click "Test Token" to verify your token is valid
5. Select an API group, endpoint path, and HTTP method from the dropdowns
6. Fill in any required parameters and click "Submit API Call"
7. View responses in the Response tab and use the Inspector for large results

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

### Parameter Input Controls

Phase 2 introduces intelligent parameter controls that adapt to the type of data being entered:

- **Enum Parameters (Dropdowns)**: Parameters with predefined values are shown as dropdown menus
  - Example: `dashboardType` offers "All", "Public", "Favorites"
  - Empty option available for optional parameters
  - Default values automatically selected

- **Boolean Parameters (Checkboxes)**: True/false parameters use checkboxes
  - Example: `objectCount`, `force`
  - Default value displayed next to checkbox
  - More intuitive than typing "true" or "false"

- **Array Parameters (Multi-Value Input)**: Array-type parameters support comma-separated values
  - Example: `id` parameter accepts multiple division IDs: "division1, division2, division3"
  - Hint text shows expected item type (string, integer, etc.)
  - Real-time validation ensures array items match expected type
  - Green border = Valid array format
  - Red border = Invalid array format with error message below

- **Body Parameters (JSON Editor)**: JSON body inputs include comprehensive real-time validation
  - Multi-line text editor with syntax checking
  - **Character count and line number display** for tracking large JSON bodies
  - Border color indicates validation status:
    - Green border = Valid JSON
    - Red border = Invalid JSON syntax
    - No border = Empty (checked separately for required fields)
  - Info text color changes with validation state for additional visual feedback
  - Validation errors shown before submission

- **Numeric Parameters (Integer/Number)**: Numeric inputs with range validation
  - Example: `timeoutSeconds` must be between 1 and 15
  - Real-time validation checks:
    - Value is a valid number (integer or decimal as required)
    - Value is within allowed minimum/maximum range
  - Tooltip shows range constraints (e.g., "Range: 1 - 604800")
  - Green border = Valid number within range
  - Red border = Invalid or out of range with error message below

- **Formatted String Parameters (Pattern/Format Validation)**: String inputs with format constraints
  - Validates email addresses (format: email)
  - Validates URLs (format: uri or url)
  - Validates dates (format: date, date-time)
  - Validates custom patterns using regex (e.g., file name restrictions)
  - Tooltip shows format requirements
  - Green border = Valid format
  - Red border = Invalid format with error message below

- **Validation Messages**:
  - Required fields are highlighted with light yellow background
  - Missing required fields trigger a validation error dialog
  - Invalid values show inline error messages with ✗ indicator
  - Pre-submission validation prevents API calls with invalid data
  - All validation errors displayed in comprehensive dialog

### Script Generation & Export

Phase 3 adds the ability to export requests as reusable scripts:

- **Export PowerShell**: Click the "Export PowerShell" button to generate a ready-to-run PowerShell script
  - Complete script includes token, headers, and all parameters
  - Saves to file and copies to clipboard automatically
  - Generated scripts are standalone and fully functional
  - Perfect for automation, documentation, or sharing with team

- **Export cURL**: Click the "Export cURL" button to generate a cURL command
  - Cross-platform compatible format
  - Copies to clipboard immediately
  - Includes proper escaping for shell environments
  - Great for testing in different environments or sharing with non-Windows users

### Template Management

The **Templates** tab provides powerful request template functionality:

1. **Saving Templates**:
   - Configure your API request with all desired parameters
   - Click "Save Template" button in the Templates tab
   - Enter a descriptive name for the template
   - Template is saved with method, path, and all parameter values

2. **Loading Templates**:
   - Navigate to the "Templates" tab
   - Select a template from the list
   - Click "Load Template" to restore the request configuration
   - All parameters will be automatically filled in

3. **Managing Templates**:
   - **Delete**: Select a template and click "Delete Template" to remove it
   - **Export**: Click "Export Templates" to save all templates to a JSON file
   - **Import**: Click "Import Templates" to load templates from a JSON file
   - Templates persist across sessions in `%USERPROFILE%\GenesysApiExplorerTemplates.json`

4. **Sharing Templates**:
   - Export your template collection as JSON
   - Share the JSON file with team members
   - Others can import to use your pre-configured requests
   - Great for onboarding and standardizing API usage

#### Pre-Configured Templates

On first launch, the application automatically includes 31 ready-to-use templates organized into 6 categories:

**Conversations (8 GET Templates):**

- **Get Active Conversations**: Retrieve all active conversations for the logged-in user
- **Get Specific Conversation Details**: Fetch details for a single conversation by ID
- **Get Conversation Recording Metadata**: Get recording metadata for a conversation
- **Get Call History**: Retrieve call history with pagination
- **Get Active Callbacks**: List all currently active callbacks
- **Get Active Calls**: List all currently active calls
- **Get Active Chats**: List all currently active chat conversations
- **Get Active Emails**: List all currently active email conversations

**Analytics (14 Templates - 5 GET, 9 POST):**

- **Get Multiple Conversations by IDs**: Retrieve multiple conversations in one request
- **Get Single Conversation Analytics**: Get analytics data for a specific conversation
- **Get Conversation Details Job Status**: Check the status of an async conversation details job
- **Get Conversation Details Job Results**: Fetch results from a completed async job
- **Get User Details Job Status**: Check the status of an async user details job
- **Query Conversation Details - Last 7 Days**: Fetch detailed conversation data for the past week
- **Query Conversation Details - Today**: Get today's conversation details with recent-first ordering
- **Query Conversation Details - By Queue**: Filter conversations by specific queue ID
- **Query Conversation Details - By Media Type**: Filter conversations by media type (voice, chat, email, etc.)
- **Query Conversation Aggregates - Daily Stats**: Get aggregated metrics by hour and queue
- **Query Conversation Aggregates - Agent Performance**: Analyze agent performance metrics by user
- **Query Conversation Transcripts**: Retrieve conversation transcripts for analysis
- **Create Conversation Details Job**: Initiate an async job for large data queries
- **Query Conversation Activity**: Get real-time conversation activity metrics

**Speech and Text Analytics (2 GET Templates):**

- **Get Speech and Text Analytics for Conversation**: Get comprehensive speech analytics for a conversation
- **Get Sentiment Data for Conversation**: Retrieve sentiment analysis data for a conversation

**Telephony (1 GET Template):**

- **Get SIP Message for Conversation**: Get the raw SIP message for a conversation

**Routing (2 GET Templates):**

- **Get Queue Details**: Get detailed information about a specific queue
- **Get Queue Members**: List all members assigned to a queue

**Users (4 GET Templates):**

- **Get User Routing Skills**: List routing skills assigned to a user
- **Get User Presence (Genesys Cloud)**: Get a user's Genesys Cloud presence status
- **Get Bulk User Presences (Genesys Cloud)**: Get presence status for multiple users at once
- **Get User Routing Status**: Fetch the routing status of a user

These templates are designed for:

- **Data Analysis**: Extract conversation data for reporting and analytics
- **Speech Analytics**: Analyze conversation quality, sentiment, and transcripts
- **Monitoring**: Track active conversations, user status, and system activity
- **Historical Analysis**: Query past conversations with flexible filters
- **Performance Metrics**: Analyze agent and queue performance
- **Routing Intelligence**: Monitor queue membership and user skills
- **Read-Only Operations**: All templates retrieve data without modifying your organization

Simply load a template, replace placeholder values (like `queue-id-goes-here`, `conversation-id-goes-here`, or `user-id-goes-here`) with your actual IDs, and submit the request.

### Response Viewer

Enhanced response viewing capabilities:

- **Toggle Raw/Formatted**: Switch between formatted JSON and raw response text
- **Response Inspector**: Click "Inspect Result" to explore large responses in a tree view
- **Progress Indicator**: Visual feedback during API calls with elapsed time display

### Transparency Log

The **Transparency Log** tab captures all activity within the application for auditing and troubleshooting:

- **Export Log**: Click the "Export Log" button to save the entire log to a timestamped text file
  - Useful for sharing logs with support teams or keeping records for compliance
  - Files are named with timestamp: `GenesysAPIExplorer_Log_YYYYMMDD_HHMMSS.txt`
- **Clear Log**: Click the "Clear Log" button to remove all log entries
  - Shows confirmation dialog to prevent accidental deletion
  - Clearing the log does not affect saved responses or request history

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

## Documentation

Comprehensive project documentation is available in the `docs/` directory:

- **[TEMPLATE_CATALOG.md](docs/TEMPLATE_CATALOG.md)** - Complete reference for all 31 templates
  - Organized by category (Conversations, Analytics, Speech Analytics, Telephony, Routing, Users)
  - Detailed description of each template
  - Parameter requirements and placeholder values
  - Usage examples and use cases
  - **Start here** for understanding available templates

- **[DEVELOPMENT_HISTORY.md](docs/DEVELOPMENT_HISTORY.md)** - Complete chronological development story
  - Project overview and philosophy
  - Development timeline across all phases
  - Detailed feature descriptions with user impact
  - Technical architecture and design decisions
  - Future roadmap and planned enhancements

- **[PROJECT_PLAN.md](docs/PROJECT_PLAN.md)** - 8-phase enhancement plan
  - Structured roadmap for future development
  - Feature priorities and dependencies
  - Implementation guidelines

- **Phase Implementation Details:**
  - [PHASE1_SUMMARY.md](docs/PHASE1_SUMMARY.md) - Core UX enhancements (token validation, history, progress)
  - [PHASE2_SUMMARY.md](docs/PHASE2_SUMMARY.md) - Advanced parameters & validation
  - [PHASE2_DEFERRED_SUMMARY.md](docs/PHASE2_DEFERRED_SUMMARY.md) - Extended validation features
  - [PHASE3_SUMMARY.md](docs/PHASE3_SUMMARY.md) - Scripting & automation
  - [PHASE4_SUMMARY.md](docs/PHASE4_SUMMARY.md) - Read-only mode & template expansion

- **[POST_CONVERSATIONS_TEMPLATES.md](docs/POST_CONVERSATIONS_TEMPLATES.md)** - Pre-configured template documentation

- **[AI_RECREATION_PROMPT.md](docs/AI_RECREATION_PROMPT.md)** - Project context for AI assistants

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
