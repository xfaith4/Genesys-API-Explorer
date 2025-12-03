# Genesys Cloud API Explorer (WPF PowerShell GUI)

PowerShell-based WPF application that mirrors the Genesys Cloud API catalog, provides transparency-first logging, and lets you inspect/save large responses, track job endpoints, and reuse favorite payloads.

---

## Features

- WPF shell with OAuth token field, Help menu, splash screen, grouped path/method selection, jobs watcher tab, schema viewer, inspector, and favorites panel
- Dynamically generated parameter editors (query/path/body/header) with required-field hints and schema preview powered by the Genesys OpenAPI definitions
- Dispatches requests with `Invoke-WebRequest`, logs every request/response, and formats big JSON results in the inspector/export dialogs
- Job Watch tab polls `/jobs` endpoints until they complete, downloads results to temp files, and exposes export/copy hooks so the UI never freezes on large payloads
- Favorites persist under `%USERPROFILE%\GenesysApiExplorerFavorites.json` and capture endpoint + payload details for reuse
- Inspector lets you explore large responses via tree view, raw text, clipboard/export, and warns before parsing huge files

---

## Requirements

- Windows PowerShell 5.1+ (with WPF libraries available). PowerShell Core is supported only on Windows hosts that expose the PresentationFramework assembly.
- Valid Genesys Cloud OAuth token (paste into the UI before submitting calls).
- API catalog JSON exported from [Genesys Cloud API Explorer](https://developer.genesys.cloud/developer-tools/#/api-explorer).
- Internet access to reach `https://api.usw2.pure.cloud` and the documentation hubs (`https://developer.genesys.cloud`, `https://help.usw2.pure.cloud`).

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
3. Select an API group, endpoint path, and HTTP method from the dropdowns
4. Fill in any required parameters and click "Submit API Call"
5. View responses in the Response tab and use the Inspector for large results

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
