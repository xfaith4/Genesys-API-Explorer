# Genesys Cloud API Explorer (PowerShell GUI)

An interactive Windows Forms GUI for exploring and testing Genesys Cloud API endpoints using PowerShell.

---

## Features

- Grouped endpoint explorer (`/api/v2/users/...`, `/conversations/...`)
- Dynamic UI for method and parameter selection
- Supports query, path, header, and body parameters
- Sends REST API requests with `Invoke-RestMethod`
- Displays response in a scrollable panel
- Saves responses to a file via SaveFileDialog
- No external modules required (pure PowerShell + WinForms)

---

## Requirements

- Windows OS with PowerShell 5.1+ or PowerShell Core (7+) with WinForms support
- A valid Genesys Cloud **OAuth token** (paste into script for now)
- `.json` export from [Genesys Cloud API Explorer](https://developer.genesys.cloud/developer-tools/#/api-explorer)

---

## Project Structure

```plaintext
genesys-api-explorer/
├── src/
│   ├── GenesysApiGuiExplorer.ps1         # Main GUI script
│   └── GenesysCloudAPIEndpoints.json     # Example endpoint file
├── README.md                             # This documentation
├── .gitignore                            # File exclusion rules
└── LICENSE                               # (Optional) Open-source license
