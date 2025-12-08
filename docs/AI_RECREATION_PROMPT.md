# AI Prompt: Recreating the Genesys Cloud API Explorer

## Overview

Create a **PowerShell WPF GUI application** that serves as an interactive API explorer for Genesys Cloud. The application provides a transparency-focused interface for discovering, testing, and documenting Genesys Cloud API endpoints with features like dynamic parameter inputs, job polling, favorites management, schema inspection, and comprehensive logging.

---

## Technical Requirements

### Platform & Language
- **Language**: PowerShell (Windows PowerShell 5.1+)
- **UI Framework**: WPF (Windows Presentation Foundation)
- **Required Assemblies**: PresentationCore, PresentationFramework, WindowsBase, System.Xaml

### External Dependencies
- **API Endpoint Catalog**: A JSON file containing the Genesys Cloud OpenAPI specification (exported from the Genesys Cloud API Explorer)
- **Network Access**: HTTP/HTTPS connectivity to Genesys Cloud API endpoints (`https://api.mypurecloud.com/api/v2`)

---

## Application Architecture

### Core Components

1. **Main Window (WPF XAML)**
   - Fixed-size application window (950x780 pixels) centered on screen
   - Menu bar with Help menu
   - Grid-based layout with the following sections:
     - Header/title area
     - OAuth token input field
     - Endpoint selection dropdowns (Group, Path, Method)
     - Parameter input panel (scrollable)
     - Favorites management panel
     - Action buttons (Submit, Save Response)
     - Tabbed output area (Response, Log, Schema, Job Watch)

2. **Splash Screen**
   - Borderless, transparent, topmost window
   - Displays application name and feature highlights
   - "Continue" button to dismiss
   - Shows on application startup

3. **Help Window**
   - Modal dialog with usage instructions
   - Links to external documentation (Developer Portal, Support)
   - "Close" button

4. **Data Inspector Window**
   - Modal dialog for examining large JSON responses
   - Tab control with:
     - **Structured view**: TreeView with hierarchical JSON navigation
     - **Raw view**: Read-only TextBox with full JSON content
   - Copy to clipboard and Export to file buttons
   - Warning prompt for files >5MB

---

## Feature Specifications

### 1. API Endpoint Catalog Loading

```
Function: Load-APIPathsFromJson
Purpose: Parse the Genesys Cloud OpenAPI JSON file and extract API paths and definitions

Input: JSON file path
Output: PSCustomObject with Paths and Definitions properties

Algorithm:
1. Read and parse JSON content
2. Locate the 'paths' section in the OpenAPI specification
3. Extract definitions/schemas for parameter validation
4. Return structured catalog object
```

### 2. Group-Based Navigation

```
Function: Build-GroupMap
Purpose: Organize API endpoints into logical groups based on URL structure

Algorithm:
1. Parse each path in the API catalog
2. Extract group name from URL pattern: /api/v2/{groupName}/...
3. Build a hashtable mapping group names to arrays of endpoints
4. Default group name "Other" for non-standard paths

Example groups: users, conversations, routing, analytics, etc.
```

### 3. Dynamic Parameter Input Generation

```
When a method is selected:
1. Clear existing parameter inputs
2. Read parameter definitions from the OpenAPI spec
3. For each parameter:
   - Create a labeled input row
   - Display parameter name, location (query/path/body/header), and required status
   - Set appropriate input control height (taller for body parameters)
   - Highlight required fields with yellow background
   - Show description as tooltip
4. Store input references in a hashtable for value retrieval
```

### 4. API Request Execution

```
Function: Submit API Call
Purpose: Execute HTTP requests to Genesys Cloud API

Steps:
1. Validate path and method selection
2. Collect parameter values from input controls
3. Build request URL:
   - Base URL: https://api.mypurecloud.com/api/v2
   - Replace path placeholders: {paramName} → actual value
   - Append query string parameters
4. Construct headers:
   - Content-Type: application/json
   - Authorization: Bearer {token}
   - Custom headers from parameters
5. Prepare body JSON if applicable
6. Execute Invoke-WebRequest
7. Log request details
8. Handle response:
   - Parse and format JSON
   - Update response display
   - Enable save button
9. Handle errors:
   - Display error message
   - Log error details
10. Detect job creation (POST to /jobs endpoints):
    - Extract job ID from response
    - Start automatic job polling
```

### 5. Job Polling System

```
Structure: JobTracker object
Properties: Timer, JobId, Path, Headers, Status, ResultFile, LastUpdate

Functions:
- Start-JobPolling: Initialize polling for a new job
- Stop-JobPolling: Cancel active polling timer
- Poll-JobStatus: Check job status via API
- Fetch-JobResults: Download completed job results
- Update-JobPanel: Refresh UI elements

Polling Logic:
1. Create DispatcherTimer with 6-second interval
2. On each tick, query job status endpoint
3. Parse status/state from response
4. Update UI with current status
5. Continue polling while status matches pending pattern:
   Regex: ^(pending|running|in[-]?progress|processing|created)$
6. On completion, fetch results and save to temp file
7. Enable result export functionality
```

### 6. Favorites Management

```
Storage Location: %USERPROFILE%\GenesysApiExplorerFavorites.json

Favorite Record Structure:
{
    "Name": "User-friendly label",
    "Path": "/api/v2/endpoint/path",
    "Method": "get",
    "Group": "groupName",
    "Parameters": [
        { "name": "paramName", "in": "query", "value": "savedValue" }
    ],
    "Timestamp": "ISO-8601 datetime"
}

Functions:
- Load-FavoritesFromDisk: Read and parse favorites JSON
- Save-FavoritesToDisk: Serialize and write favorites
- Build-FavoritesCollection: Convert to ArrayList
- Refresh-FavoritesList: Update ListBox display

Operations:
- Save: Capture current endpoint, method, and parameter values
- Load: Restore endpoint selection and populate parameter values
- Deduplication: Replace existing favorite with same name
```

### 7. Schema Viewer

```
Functions:
- Resolve-SchemaReference: Follow $ref pointers in OpenAPI definitions
- Format-SchemaType: Generate human-readable type strings
- Flatten-Schema: Recursively expand schema into field list
- Get-ResponseSchema: Extract schema from method's response definitions
- Update-SchemaList: Populate ListView with schema fields

Schema Display Columns:
- Field: Hierarchical field path (e.g., "user.email", "items[].id")
- Type: Data type (string, integer, array of object, etc.)
- Required: Yes/No
- Description: Field documentation from OpenAPI spec

Recursion Limits: Maximum depth of 10 to prevent infinite loops
```

### 8. Data Inspector

```
Purpose: Examine large JSON responses with tree navigation

Features:
- TreeView with expandable nodes
- Automatic expansion of first 2 levels
- Array truncation at 150 items with [...] indicator
- Copy JSON to clipboard
- Export JSON to file
- Large file warning (>5MB)

Function: Populate-InspectorTree
Recursively builds TreeViewItem nodes from parsed JSON
- Objects: Display "(object)" header, add child nodes for properties
- Arrays: Display "(array)" header, add child nodes for items
- Primitives: Display "key: value" format
```

### 9. Transparency Logging

```
Function: Add-LogEntry
Purpose: Maintain comprehensive audit trail

Log Format: [yyyy-MM-dd HH:mm:ss] Message

Logged Events:
- Application startup
- Favorites loaded/saved
- Endpoint selection changes
- Request sent (method, URL)
- Response received (status code, size)
- Errors encountered
- Job status changes
- File exports
- Inspector actions
```

### 10. Response Export

```
Export Options:
1. Save Response button: Export current response to JSON file
2. Inspector Export: Export from data inspector view
3. Job Results Export: Export completed job results

Implementation:
- Use Microsoft.Win32.SaveFileDialog
- Default filter: "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
- UTF-8 encoding
- Log export path
```

---

## UI Layout Specification

### Main Window XAML Structure

```xml
<Window>
  <DockPanel>
    <Menu DockPanel.Dock="Top">
      <MenuItem Header="_Help">
        <MenuItem Header="Show Help"/>
        <Separator/>
        <MenuItem Header="Developer Portal"/>
        <MenuItem Header="Genesys Support"/>
      </MenuItem>
    </Menu>
    
    <Grid>
      <!-- Row 0: Title -->
      <TextBlock Text="Genesys Cloud API Explorer" FontSize="20"/>
      
      <!-- Row 1: Token Input -->
      <StackPanel Orientation="Horizontal">
        <TextBlock Text="OAuth Token:"/>
        <TextBox Name="TokenInput" Width="500"/>
        <TextBlock Text="(kept in memory only)"/>
      </StackPanel>
      
      <!-- Row 2: Endpoint Selection -->
      <Grid>
        <StackPanel> <!-- Group --> </StackPanel>
        <StackPanel> <!-- Path --> </StackPanel>
        <StackPanel> <!-- Method --> </StackPanel>
      </Grid>
      
      <!-- Row 3: Parameters -->
      <Border>
        <ScrollViewer Height="220">
          <StackPanel Name="ParameterPanel"/>
        </ScrollViewer>
      </Border>
      
      <!-- Row 4: Favorites -->
      <Border>
        <Grid>
          <ListBox Name="FavoritesList"/>
          <StackPanel>
            <TextBox Name="FavoriteNameInput"/>
            <Button Name="SaveFavoriteButton"/>
          </StackPanel>
        </Grid>
      </Border>
      
      <!-- Row 5: Action Buttons -->
      <StackPanel Orientation="Horizontal">
        <Button Name="SubmitButton"/>
        <Button Name="SaveButton"/>
        <TextBlock Name="StatusText"/>
      </StackPanel>
      
      <!-- Row 6: Output Tabs -->
      <TabControl>
        <TabItem Header="Response">
          <Button Name="InspectResponseButton"/>
          <TextBox Name="ResponseText"/>
        </TabItem>
        <TabItem Header="Transparency Log">
          <TextBox Name="LogText"/>
        </TabItem>
        <TabItem Header="Schema">
          <ListView Name="SchemaList"/>
        </TabItem>
        <TabItem Header="Job Watch">
          <StackPanel>
            <TextBlock Name="JobIdText"/>
            <TextBlock Name="JobStatusText"/>
            <TextBlock Name="JobUpdatedText"/>
            <Button Name="FetchJobResultsButton"/>
            <Button Name="ExportJobResultsButton"/>
            <TextBlock Name="JobResultsPath"/>
          </StackPanel>
        </TabItem>
      </TabControl>
    </Grid>
  </DockPanel>
</Window>
```

---

## Event Handlers

### Selection Changed Events

1. **GroupCombo.SelectionChanged**
   - Clear dependent controls (path, method, parameters)
   - Populate PathCombo with paths in selected group
   - Update status text

2. **PathCombo.SelectionChanged**
   - Clear dependent controls (method, parameters)
   - Populate MethodCombo with available HTTP methods
   - Update status text

3. **MethodCombo.SelectionChanged**
   - Clear parameters panel
   - Generate parameter inputs from OpenAPI spec
   - Load pending favorite parameters if applicable
   - Update schema viewer with response schema

4. **FavoritesList.SelectionChanged**
   - Extract favorite details
   - Set group, path, method selections
   - Queue parameter values for population after method selection

### Button Click Events

1. **SubmitButton.Click**: Execute API request
2. **SaveButton.Click**: Export response to file
3. **SaveFavoriteButton.Click**: Save current configuration as favorite
4. **InspectResponseButton.Click**: Open data inspector
5. **FetchJobResultsButton.Click**: Manually fetch job results
6. **ExportJobResultsButton.Click**: Export job results to file
7. **HelpMenuItem.Click**: Show help window
8. **HelpDevLink.Click**: Launch developer portal URL
9. **HelpSupportLink.Click**: Launch support portal URL

---

## Global Variables

```powershell
$ApiBaseUrl = "https://api.mypurecloud.com/api/v2"
$DeveloperDocsUrl = "https://developer.genesys.cloud"
$SupportDocsUrl = "https://help.mypurecloud.com"

$JobTracker = [PSCustomObject]@{
    Timer      = $null
    JobId      = $null
    Path       = $null
    Headers    = @{}
    Status     = ""
    ResultFile = ""
    LastUpdate = ""
}

$script:LastResponseText = ""
$script:LastResponseRaw = ""
$script:LastResponseFile = ""
$paramInputs = @{}
$pendingFavoriteParameters = $null
```

---

## Error Handling

1. **JSON Parsing Errors**: Catch and display user-friendly messages
2. **API Request Failures**: Extract status code and error message, log details
3. **File I/O Errors**: Warn user with MessageBox
4. **Missing Required Files**: Display error and exit gracefully
5. **Large File Warnings**: Prompt user before processing >5MB files
6. **Clipboard Access**: Check command availability before use

---

## Testing Requirements

### Syntax Validation
- Use PowerShell Parser to validate script syntax
- Validate JSON endpoint catalog structure

### Unit Tests
- Test Build-GroupMap with sample paths
- Test Get-GroupForPath pattern matching
- Test Job-StatusIsPending status detection

### Integration Tests
- Verify window creation
- Verify control binding
- Verify event handler registration

---

## File Structure

```
project/
├── GenesysCloudAPIExplorer.ps1    # Main application script
├── GenesysCloudAPIEndpoints.json  # API endpoint catalog
├── README.md                      # Documentation
└── .github/
    └── workflows/
        └── test.yml               # CI/CD pipeline
```

---

## Usage Instructions

1. **Prerequisites**: Windows PowerShell 5.1+ with WPF support
2. **Setup**: Place script and JSON catalog in same directory
3. **Launch**: Execute `.\GenesysCloudAPIExplorer.ps1`
4. **Authentication**: Paste OAuth token in the token field
5. **Navigation**: Select Group → Path → Method from dropdowns
6. **Parameters**: Fill in required and optional parameters
7. **Execute**: Click "Submit API Call"
8. **Analyze**: Use tabs to view response, logs, schema, or job status
9. **Save**: Export responses or save favorites for reuse

---

## Key Implementation Notes

1. **XAML Parsing**: Use `[System.Windows.Markup.XamlReader]::Parse()` for dynamic UI creation
2. **Timer Management**: Use `System.Windows.Threading.DispatcherTimer` for UI-safe polling
3. **JSON Handling**: PowerShell's `ConvertFrom-Json` and `ConvertTo-Json` with `-Depth` parameter
4. **URL Encoding**: Use `[uri]::EscapeDataString()` for parameter values
5. **Dialog Windows**: Set `Owner` property for proper modal behavior
6. **Thread Safety**: All UI updates happen on the dispatcher thread via event handlers
7. **Memory Management**: Store temp files in `$env:TEMP`, clean up file references on new requests
