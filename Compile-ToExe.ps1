# Compile Genesys Cloud API Explorer to EXE
# This script uses PS2EXE to compile the PowerShell script into a standalone executable

# Step 1: Install PS2EXE if not already installed
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Installing PS2EXE module..." -ForegroundColor Yellow
    Install-Module -Name ps2exe -Scope CurrentUser -Force
    Write-Host "PS2EXE installed successfully!" -ForegroundColor Green
}

# Import the module
Import-Module ps2exe

# Define paths
$ScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "GenesysCloudAPIExplorer.ps1"
$OutputPath = Join-Path -Path $PSScriptRoot -ChildPath "GenesysCloudAPIExplorer.exe"
$IconPath = Join-Path -Path $PSScriptRoot -ChildPath "icon.ico" # Optional: add an icon file

# Compilation parameters
$params = @{
    InputFile      = $ScriptPath
    OutputFile     = $OutputPath
    NoConsole      = $false  # Set to $true to hide console window (GUI only)
    NoOutput       = $false
    NoError        = $false
    RequireAdmin   = $false  # Set to $true if admin rights needed
    STA            = $true  # Required for WPF applications
    NoVisualStyles = $false
    ExitOnCancel   = $true
    Title          = "Genesys Cloud API Explorer"
    Description    = "API Explorer for Genesys Cloud"
    Company        = "Your Company"
    Product        = "Genesys Cloud API Explorer"
    Copyright      = "Copyright © 2024"
    Version        = "1.0.0.0"
    Verbose        = $true
}

# Add icon if it exists
if (Test-Path $IconPath) {
    $params.IconFile = $IconPath
}

Write-Host "`nCompiling PowerShell script to EXE..." -ForegroundColor Cyan
Write-Host "Input:  $ScriptPath" -ForegroundColor Gray
Write-Host "Output: $OutputPath" -ForegroundColor Gray
Write-Host ""

try {
    # Compile the script
    Invoke-PS2EXE @params
    
    if (Test-Path $OutputPath) {
        $exeInfo = Get-Item $OutputPath
        Write-Host "`n✓ Compilation successful!" -ForegroundColor Green
        Write-Host "  Executable: $OutputPath" -ForegroundColor Green
        Write-Host "  Size: $([math]::Round($exeInfo.Length / 1MB, 2)) MB" -ForegroundColor Green
        Write-Host "`nIMPORTANT NOTES:" -ForegroundColor Yellow
        Write-Host "1. Copy the OpsConsole module and resource files into the executable directory:" -ForegroundColor White
        Write-Host "   - apps/OpsConsole/OpsConsole.psd1" -ForegroundColor Gray
        Write-Host "   - apps/OpsConsole/OpsConsole.psm1" -ForegroundColor Gray
        Write-Host "   - apps/OpsConsole/Resources/GenesysCloudAPIExplorer.ps1" -ForegroundColor Gray
        Write-Host "   - apps/OpsConsole/Resources/DefaultTemplates.json" -ForegroundColor Gray
        Write-Host "   - apps/OpsConsole/Resources/ExamplePostBodies.json" -ForegroundColor Gray
        Write-Host "   - apps/OpsConsole/Resources/GenesysCloudAPIEndpoints.json" -ForegroundColor Gray
        Write-Host "2. User templates will be stored in: Documents\GenesysCloudAPIExplorer\" -ForegroundColor White
        Write-Host "3. The executable is NOT code-signed. Windows may show a warning on first run." -ForegroundColor White
    }
    else {
        Write-Host "✗ Compilation failed - output file not created" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Compilation error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
