# Compiling Genesys Cloud API Explorer to EXE

## Overview

This guide explains how to compile the PowerShell-based Genesys Cloud API Explorer into a standalone Windows executable (.exe) file.

## Method: Using PS2EXE

**PS2EXE** is a PowerShell module that converts PowerShell scripts into executable files. It wraps the script in a C# host application.

### Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- Internet connection (for initial module installation)
- Execution policy allowing script execution

### Quick Start

1. **Run the compilation script**:
   ```powershell
   .\Compile-ToExe.ps1
   ```

2. **Wait for compilation** (usually 10-30 seconds)

3. **Find your executable**: `GenesysCloudAPIExplorer.exe` will be created in the same directory

### Manual Compilation

If you prefer to compile manually:

```powershell
# Install PS2EXE
Install-Module -Name ps2exe -Scope CurrentUser -Force

# Import the module
Import-Module ps2exe

# Compile the script
Invoke-PS2EXE `
    -InputFile "GenesysCloudAPIExplorer.ps1" `
    -OutputFile "GenesysCloudAPIExplorer.exe" `
    -STA `
    -NoConsole:$false `
    -Title "Genesys Cloud API Explorer" `
    -Version "1.0.0.0"
```

## Important Considerations

### Required Files

The executable requires these JSON files in the **same directory**:
- `DefaultTemplates.json` - Default API templates
- `ExamplePostBodies.json` - Example request bodies
- `GenesysCloudAPIEndpoints.json` - API endpoint catalog

**Do not delete these files** - the EXE reads them at runtime.

### User Data Storage

User-specific data is stored separately in:
```
C:\Users\<username>\Documents\GenesysCloudAPIExplorer\
```

This includes:
- User templates
- Favorites
- Logs

### Windows SmartScreen Warning

Since the executable is not code-signed, Windows may show a warning:
- **"Windows protected your PC"**
- Click **"More info"** → **"Run anyway"**

To avoid this warning, you would need to:
1. Code-sign the executable with a valid certificate (~$200-500/year)
2. Or distribute the PowerShell script instead

### Antivirus False Positives

Some antivirus software may flag PS2EXE-compiled executables as suspicious. This is a known issue with PowerShell-to-EXE converters. Options:
- Add an exception in your antivirus
- Use the PowerShell script directly
- Code-sign the executable

## Distribution

### Option 1: Distribute EXE + JSON Files

Create a folder with:
```
GenesysCloudAPIExplorer/
├── GenesysCloudAPIExplorer.exe
├── DefaultTemplates.json
├── ExamplePostBodies.json
└── GenesysCloudAPIEndpoints.json
```

Zip this folder for distribution.

### Option 2: Create an Installer

For a more professional distribution, consider creating an installer using:
- **Inno Setup** (free)
- **WiX Toolset** (free)
- **Advanced Installer** (commercial)

### Option 3: Keep as PowerShell Script

Advantages of distributing as `.ps1`:
- No compilation needed
- Easier to update
- No antivirus false positives
- Users can inspect the code
- Smaller file size

## Compilation Options

### Hide Console Window (GUI Only)

If you want to hide the console window:
```powershell
Invoke-PS2EXE -InputFile "GenesysCloudAPIExplorer.ps1" `
              -OutputFile "GenesysCloudAPIExplorer.exe" `
              -NoConsole `
              -STA
```

**Note**: This hides ALL console output, including error messages.

### Require Administrator Rights

If the application needs admin privileges:
```powershell
Invoke-PS2EXE -InputFile "GenesysCloudAPIExplorer.ps1" `
              -OutputFile "GenesysCloudAPIExplorer.exe" `
              -RequireAdmin `
              -STA
```

### Add Custom Icon

1. Create or obtain an `.ico` file
2. Save it as `icon.ico` in the same directory
3. Compile with icon:
```powershell
Invoke-PS2EXE -InputFile "GenesysCloudAPIExplorer.ps1" `
              -OutputFile "GenesysCloudAPIExplorer.exe" `
              -IconFile "icon.ico" `
              -STA
```

## Troubleshooting

### "PS2EXE module not found"
```powershell
Install-Module -Name ps2exe -Scope CurrentUser -Force
```

### "Execution policy" error
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### EXE doesn't start
- Check that all JSON files are in the same directory
- Run from PowerShell to see error messages:
  ```powershell
  .\GenesysCloudAPIExplorer.exe
  ```

### "File is too large" error
The compiled EXE will be larger than the original script (typically 5-10 MB). This is normal as it includes the PowerShell runtime.

## Alternative: PowerShell App Deployment Toolkit

For enterprise deployment, consider using **PowerShell App Deployment Toolkit (PSADT)**:
- Better logging
- User interaction dialogs
- Installation/uninstallation support
- No compilation needed

## Recommendations

**For personal use**: Use the PowerShell script directly (`.ps1`)

**For team distribution**: Compile to EXE for easier deployment

**For enterprise deployment**: Use PSADT or create a proper installer

**For public distribution**: Keep as PowerShell script or invest in code signing

