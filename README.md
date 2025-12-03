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
genesys-api-explorer/
├── src/
│   ├── GenesysApiGuiExplorer.ps1         # Main GUI script
│   └── GenesysCloudAPIEndpoints.json     # Example endpoint file
├── README.md                             # This documentation
├── .gitignore                            # File exclusion rules
└── LICENSE                               # (Optional) Open-source license
