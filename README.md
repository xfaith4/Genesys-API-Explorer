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

### Phase 1 Enhancements
- **Enhanced Token Management**: Test Token button to instantly verify OAuth token validity with clear status indicators (✓ Valid, ✗ Invalid, ⚠ Unknown)
- **Request History**: Automatically tracks the last 50 API requests with timestamp, method, path, status, and duration. Easily replay previous requests with one click
- **Progress Indicators**: Visual progress indicator (⏳) during API calls with elapsed time tracking and responsive UI
- **Enhanced Response Viewer**: Toggle between raw and formatted JSON views, with improved response display
- **Detailed Error Display**: Comprehensive error information including HTTP status codes, headers, and response body for better troubleshooting

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

### Phase 3 Enhancements (New!)
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

#### Pre-Configured POST Conversation Templates

On first launch, the application automatically includes 12 ready-to-use templates for common POST conversation operations:

**Conversation Management Templates:**
- **Create Callback - Basic**: Schedule a callback with customer information
- **Create Outbound Call**: Initiate an outbound call to a customer
- **Create Web Chat Conversation**: Start a new web chat interaction
- **Create Email Conversation**: Initiate an outbound email conversation
- **Create Outbound Message (SMS)**: Send an SMS message to a customer
- **Replace Participant with User**: Transfer a participant to a specific user
- **Bulk Disconnect Callbacks**: Disconnect multiple scheduled callbacks at once
- **Force Disconnect Conversation**: Emergency conversation teardown
- **Create Participant Callback**: Create a callback for an existing participant

**Analytics Templates:**
- **Query Conversation Details - Last 7 Days**: Fetch conversation analytics data

**Messaging Templates:**
- **Send Agentless Outbound Message**: Send automated messages without agent assignment

**Quality Templates:**
- **Create Quality Evaluation**: Create a quality evaluation for a conversation

These templates include:
- Complete request body JSON with placeholder values
- All required parameters pre-configured
- Descriptive names for easy identification
- Proper structure for immediate use or customization

Simply load a template, replace placeholder values (like `queue-id-goes-here`) with your actual IDs, and submit the request.

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
