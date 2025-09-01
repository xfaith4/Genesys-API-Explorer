# Genesys Cloud API Explorer (WPF)

This is a WPF application that lets Genesys Cloud engineers explore and test API endpoints more efficiently than the web-based developer portal. It loads the Genesys Cloud API Swagger definition (v2) and allows you to:

- Browse API endpoints by category (in a TreeView).
- Log in with Genesys Cloud (OAuth 2.0) from within the app.
- Auto-generate request body forms for complex APIs (especially conversations-related endpoints).
- Send requests and view formatted responses.

## Features

- **Fast API Spec Loading:** Uses a local copy of the Genesys Cloud API Swagger (embedded in the app) for instant access to all endpoints.
- **Dynamic Forms:** The app reads the JSON schema for an endpoint’s body and builds input fields automatically.
- **OAuth Integration:** Built-in OAuth 2.0 implicit login via an embedded Edge browser (WebView2). Supports all Genesys Cloud regions.
- **One-click Requests:** Simply fill the form and hit Submit to call the API. Responses (JSON) are shown in the app and can be copied or saved.

## Prerequisites

- **.NET 6 SDK or higher** to build the project.
- **Visual Studio 2022** (or VS Code with .NET extensions) for development, or the .NET CLI.
- **Genesys Cloud account** with an OAuth Client setup:
  - Create an OAuth Client in Genesys Cloud Admin with **Implicit Grant** (for login) or **Client Credentials** (for service auth).
  - For implicit, add a Redirect URI like `http://localhost:8080` (used by this app).
  - Note the Client ID (and Client Secret if using Client Credentials).
- **Microsoft Edge WebView2 runtime** installed (if you have up-to-date Edge browser, you likely have this). The OAuth control requires WebView2[1](https://github.com/MyPureCloud/oauth-webview-dotnet).

## Setup and Build

1. **Clone or Extract the Project:** Ensure all files (as listed above) are in a folder. Open `GenesysApiExplorer.sln` in Visual Studio.
2. **Restore NuGet Packages:** The project uses **GenesysCloudOAuthWebView.Wpf** (and its dependency Microsoft.Web.WebView2). VS should restore these automatically. If not, run `dotnet restore`.
3. **Insert OAuth Client ID:** In `EndpointViewModel.cs`, find `YOUR-CLIENT-ID-HERE` in the `Login()` method. Replace it with your Genesys Cloud OAuth Client ID. (The app currently uses implicit grant. If you prefer Client Credentials, you can modify the `Login()` method to use an HTTP token request instead.)
4. **Build the Project:** Build in Release mode to prepare for publishing.

## Publishing and Deployment

- The project includes a Publish profile for a **single-file exe**. You can publish via Visual Studio (Publish -> FolderProfile) or using CLI:
  ```