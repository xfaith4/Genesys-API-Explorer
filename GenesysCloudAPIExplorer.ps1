<#
.SYNOPSIS
    Genesys Cloud API Explorer GUI Tool (WPF)

.DESCRIPTION
    Uses WPF to provide a more structured API explorer experience with
    grouped navigation, dynamic parameter inputs, and a transparency-focused
    log so every request/response step is visible.

.NOTES
    - Valid JSON catalog required from the Genesys Cloud API Explorer.
    - Paste your OAuth token into the supplied field before sending requests.
#>

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Xaml

$DeveloperDocsUrl = "https://developer.genesys.cloud"
$SupportDocsUrl = "https://help.mypurecloud.com"

function Launch-Url {
    param ([string]$Url)

    if (-not $Url) { return }
    try {
        Start-Process -FilePath $Url
    } catch {
        Write-Warning "Unable to open URL '$Url': $($_.Exception.Message)"
    }
}

function Show-HelpWindow {
    $helpXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Explorer Help" Height="420" Width="520" ResizeMode="NoResize" WindowStartupLocation="CenterOwner">
  <Border Margin="10" Padding="12" BorderBrush="LightGray" BorderThickness="1" Background="White">
    <StackPanel>
      <TextBlock Text="Genesys Cloud API Explorer Help" FontSize="16" FontWeight="Bold" Margin="0 0 0 8"/>
      <TextBlock TextWrapping="Wrap">
        This explorer mirrors the Genesys Cloud API catalog while keeping transparency front and center. Use the grouped navigator to select any endpoint, provide query/path/body values, and press Submit to send requests.
      </TextBlock>
      <TextBlock TextWrapping="Wrap" Margin="0 6 0 0">
        Feature highlights: dynamic parameter rendering, large payload inspector/export, schema viewer, job watcher for bulk requests, and favorites storage alongside logs that capture every action.
      </TextBlock>
      <StackPanel Margin="0 12 0 0">
        <TextBlock FontWeight="Bold">Usage notes</TextBlock>
        <TextBlock TextWrapping="Wrap" Margin="0 2 0 0">
          - Provide an OAuth token before submitting calls. An invalid token will surface through the log and response panel.
        </TextBlock>
        <TextBlock TextWrapping="Wrap" Margin="0 2 0 0">
          - When a job endpoint returns an identifier, the Job Watch tab polls it automatically and saves results to a temp file you can inspect/export.
        </TextBlock>
        <TextBlock TextWrapping="Wrap" Margin="0 2 0 0">
          - Favorites persist under your Windows profile (~\GenesysApiExplorerFavorites.json) and store both endpoint metadata and body payloads.
        </TextBlock>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 12 0 0">
        <Button Name="OpenDevDocs" Width="140" Height="30" Content="Developer Portal" Margin="0 0 10 0"/>
        <Button Name="OpenSupportDocs" Width="140" Height="30" Content="Genesys Support"/>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 8 0 0">
        <Button Name="CloseHelp" Width="90" Height="28" Content="Close"/>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
"@

    $helpWindow = [System.Windows.Markup.XamlReader]::Parse($helpXaml)
    if (-not $helpWindow) {
        Write-Warning "Unable to instantiate help window."
        return
    }

    $openDevButton = $helpWindow.FindName("OpenDevDocs")
    $openSupportButton = $helpWindow.FindName("OpenSupportDocs")
    $closeButton = $helpWindow.FindName("CloseHelp")

    if ($openDevButton) {
        $openDevButton.Add_Click({ Launch-Url -Url $DeveloperDocsUrl })
    }
    if ($openSupportButton) {
        $openSupportButton.Add_Click({ Launch-Url -Url $SupportDocsUrl })
    }
    if ($closeButton) {
        $closeButton.Add_Click({ $helpWindow.Close() })
    }

    if ($Window) {
        $helpWindow.Owner = $Window
    }
    $helpWindow.ShowDialog() | Out-Null
}

function Show-SettingsDialog {
    param (
        [string]$CurrentJsonPath
    )

    $settingsXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Endpoints Configuration" Height="360" Width="760"
        MinHeight="340" MinWidth="640"
        ResizeMode="CanResizeWithGrip"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False">
  <StackPanel Margin="20" VerticalAlignment="Top" HorizontalAlignment="Stretch">
    <TextBlock Text="Genesys Cloud API Endpoints Configuration" FontSize="14" FontWeight="Bold" Margin="0 0 0 15"/>

    <StackPanel Margin="0 0 0 15">
      <TextBlock Text="Current Endpoints File:" FontWeight="Bold" Margin="0 0 0 5"/>
      <TextBox Name="CurrentPathText" IsReadOnly="True" Height="30" Padding="8" Background="#F5F5F5"
               HorizontalAlignment="Stretch" MinWidth="520" TextWrapping="Wrap"/>
    </StackPanel>

    <StackPanel Margin="0 0 0 15">
      <TextBlock Text="Upload Custom Endpoints JSON:" FontWeight="Bold" Margin="0 0 0 8"/>
      <StackPanel Orientation="Horizontal">
        <TextBox Name="SelectedFileText" Height="30" Padding="8" IsReadOnly="True" Margin="0 0 10 0" MinWidth="300"
                 MinWidth="400" HorizontalAlignment="Stretch"/>
        <Button Name="BrowseButton" Content="Browse..." Width="100" Height="30"/>
      </StackPanel>
      <TextBlock Text="Select a JSON file containing Genesys Cloud API endpoint definitions." Foreground="Gray" Margin="0 8 0 0" TextWrapping="Wrap"/>
    </StackPanel>

    <StackPanel Margin="0 0 0 15">
      <TextBlock Text="Note: The JSON file must contain a 'paths' property with API endpoint definitions." Foreground="#555555" TextWrapping="Wrap" FontSize="11" FontStyle="Italic"/>
    </StackPanel>

    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 20 0 0">
      <Button Name="ApplyButton" Content="Apply" Width="100" Height="32" Margin="0 0 10 0"/>
      <Button Name="CancelButton" Content="Cancel" Width="100" Height="32"/>
    </StackPanel>
  </StackPanel>
</Window>
"@

    $settingsWindow = [System.Windows.Markup.XamlReader]::Parse($settingsXaml)
    $currentPathText = $settingsWindow.FindName("CurrentPathText")
    $selectedFileText = $settingsWindow.FindName("SelectedFileText")
    $browseButton = $settingsWindow.FindName("BrowseButton")
    $applyButton = $settingsWindow.FindName("ApplyButton")
    $cancelButton = $settingsWindow.FindName("CancelButton")

    $currentPathText.Text = $CurrentJsonPath

    # Use script scope for the selected file so closures can access/modify it
    $script:SettingsDialogSelectedFile = ""

    $browseButton.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        $openFileDialog.InitialDirectory = Split-Path -Parent $CurrentJsonPath

        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:SettingsDialogSelectedFile = $openFileDialog.FileName
            $selectedFileText.Text = $script:SettingsDialogSelectedFile
        }
    })

    $applyButton.Add_Click({
        if (-not $script:SettingsDialogSelectedFile) {
            [System.Windows.MessageBox]::Show("Please select a JSON file.", "No File Selected", "OK", "Information")
            return
        }

        if (-not (Test-Path -Path $script:SettingsDialogSelectedFile)) {
            [System.Windows.MessageBox]::Show("The selected file does not exist.", "File Not Found", "OK", "Error")
            return
        }

        try {
            $testJson = Get-Content -Path $script:SettingsDialogSelectedFile -Raw | ConvertFrom-Json -ErrorAction Stop

            # Verify the JSON has required structure
            $hasPaths = $false
            foreach ($prop in $testJson.PSObject.Properties) {
                if ($prop.Value -and $prop.Value.paths) {
                    $hasPaths = $true
                    break
                }
            }

            if (-not $hasPaths) {
                [System.Windows.MessageBox]::Show("The selected file does not contain valid Genesys Cloud API endpoint definitions (missing 'paths' property).", "Invalid Format", "OK", "Error")
                return
            }

            $settingsWindow.DialogResult = $true
            $settingsWindow.Close()
        } catch {
            [System.Windows.MessageBox]::Show("Error reading JSON file: $($_.Exception.Message)", "JSON Error", "OK", "Error")
        }
    })

    $cancelButton.Add_Click({
        $settingsWindow.DialogResult = $false
        $settingsWindow.Close()
    })

    $settingsWindow.ShowDialog() | Out-Null

    if ($settingsWindow.DialogResult) {
        return $script:SettingsDialogSelectedFile
    } else {
        return $null
    }
}

function Show-SplashScreen {
    $splashXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Genesys Cloud  Explorer" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        WindowStyle="None" AllowsTransparency="True" Background="White" Topmost="True"
        SizeToContent="WidthAndHeight" MinWidth="520" MinHeight="320">
  <Border Margin="10" Padding="14" BorderBrush="#FF2C2C2C" BorderThickness="1" CornerRadius="6" Background="#FFF8F9FB">
    <StackPanel>
      <TextBlock Text="Genesys Cloud  Explorer" FontSize="18" FontWeight="Bold"/>
      <TextBlock Text="Instant access to every Genesys Cloud endpoint with schema insight, job tracking, and saved favorites." TextWrapping="Wrap" Margin="0 6"/>
      <TextBlock Text="Features in this release:" FontWeight="Bold" Margin="0 8 0 0"/>
      <TextBlock Text="• Grouped endpoint navigation with parameter assistance." Margin="0 2"/>
      <TextBlock Text="• Transparency log, schema viewer, and large-response inspection/export." Margin="0 2"/>
      <TextBlock Text="• Job Watch tab polls bulk jobs and stages outputs in temp files for export." Margin="0 2"/>
      <TextBlock Text="• Favorites persist locally and include payloads for reuse." Margin="0 2"/>
      <TextBlock TextWrapping="Wrap" Margin="0 10 0 0">
        Visit the Genesys Cloud developer documentation or help center from the Help menu when you’re ready for deeper reference.
      </TextBlock>
      <Button Name="ContinueButton" Content="Continue" Width="120" Height="32" HorizontalAlignment="Right" Margin="0 12 0 0"/>
    </StackPanel>
  </Border>
</Window>
"@

    $splashWindow = [System.Windows.Markup.XamlReader]::Parse($splashXaml)
    if (-not $splashWindow) {
        return
    }

    $continueButton = $splashWindow.FindName("ContinueButton")
    if ($continueButton) {
        $continueButton.Add_Click({
            $splashWindow.Close()
        })
    }

    $splashWindow.ShowDialog() | Out-Null
}

function Load-PathsFromJson {
    param ([Parameter(Mandatory = $true)] [string]$JsonPath)

    $json = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
    foreach ($prop in $json.PSObject.Properties) {
        if ($prop.Value -and $prop.Value.paths) {
            return [PSCustomObject]@{
                Paths       = $prop.Value.paths
                Definitions = $prop.Value.definitions
            }
        }
    }

    throw "Cannot locate a 'paths' section in '$JsonPath'."
}

function Build-GroupMap {
    param ([Parameter(Mandatory = $true)] $Paths)

    $map = @{}
    foreach ($prop in $Paths.PSObject.Properties) {
        $path = $prop.Name
        if ($path -match "^//v2/([^/]+)") {
            $group = $Matches[1]
        }
        else {
            $group = "Other"
        }

        if (-not $map.ContainsKey($group)) {
            $map[$group] = @()
        }

        $map[$group] += $path
    }

    return $map
}

function Get-PathObject {
    param (
        $ApiPaths,
        [string]$Path
    )

    $prop = $ApiPaths.PSObject.Properties | Where-Object { $_.Name -eq $Path }
    return $prop.Value
}

function Get-MethodObject {
    param (
        $PathObject,
        [string]$MethodName
    )

    $methodProp = $PathObject.PSObject.Properties | Where-Object { $_.Name -eq $MethodName }
    return $methodProp.Value
}

function Get-GroupForPath {
    param ([string]$Path)

    if ($Path -match "^/api/v2/([^/]+)") {
        return $Matches[1]
    }

    return "Other"
}

function Get-ParameterControlValue {
    param ($Control)

    if (-not $Control) { return $null }

    # Handle CheckBox (wrapped in StackPanel)
    if ($Control.ValueControl -and $Control.ValueControl -is [System.Windows.Controls.CheckBox]) {
        $checkBox = $Control.ValueControl
        if ($checkBox.IsChecked -eq $true) {
            return "true"
        } elseif ($checkBox.IsChecked -eq $false) {
            return "false"
        }
        return $null
    }

    # Handle ComboBox
    if ($Control -is [System.Windows.Controls.ComboBox]) {
        $value = $Control.SelectedItem
        if ($value) {
            return $value.ToString()
        }
        return $null
    }

    # Handle TextBox
    if ($Control -is [System.Windows.Controls.TextBox]) {
        return $Control.Text
    }

    return $null
}

function Set-ParameterControlValue {
    param (
        $Control,
        $Value
    )

    if (-not $Control) { return }

    # Handle CheckBox (wrapped in StackPanel)
    if ($Control.ValueControl -and $Control.ValueControl -is [System.Windows.Controls.CheckBox]) {
        $checkBox = $Control.ValueControl
        if ($Value -eq "true" -or $Value -eq $true) {
            $checkBox.IsChecked = $true
        } elseif ($Value -eq "false" -or $Value -eq $false) {
            $checkBox.IsChecked = $false
        } else {
            $checkBox.IsChecked = $null
        }
        return
    }

    # Handle ComboBox
    if ($Control -is [System.Windows.Controls.ComboBox]) {
        $Control.SelectedItem = $Value
        return
    }

    # Handle TextBox
    if ($Control -is [System.Windows.Controls.TextBox]) {
        $Control.Text = $Value
        return
    }
}

function Test-JsonString {
    param ([string]$JsonString)

    if ([string]::IsNullOrWhiteSpace($JsonString)) {
        return $true  # Empty is valid (will be handled by required check)
    }

    try {
        $null = $JsonString | ConvertFrom-Json -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Export-PowerShellScript {
    param (
        [string]$Method,
        [string]$Path,
        [hashtable]$Parameters,
        [string]$Token,
        [string]$Region = "mypurecloud.com"
    )

    $script = @"
# Generated PowerShell script for Genesys Cloud API
# Endpoint: $Method $Path
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

`$token = "$Token"
`$region = "$Region"
`$baseUrl = "https://api.`$region"
`$path = "$Path"

"@

    # Build headers
    $script += @"
`$headers = @{
    "Authorization" = "Bearer `$token"
    "Content-Type" = "application/json"
}

"@

    # Build query parameters
    $queryParams = @()
    $pathParams = @{}
    $bodyContent = ""

    if ($Parameters) {
        foreach ($paramName in $Parameters.Keys) {
            $paramValue = $Parameters[$paramName]
            if ([string]::IsNullOrWhiteSpace($paramValue)) { continue }

            # Determine parameter type based on name and path
            $pattern = "{$paramName}"
            if ($Path -match [regex]::Escape($pattern)) {
                # Path parameter
                $pathParams[$paramName] = $paramValue
            }
            elseif ($paramName -eq "body") {
                # Body parameter
                $bodyContent = $paramValue
            }
            else {
                # Query parameter
                $queryParams += "$paramName=$([System.Uri]::EscapeDataString($paramValue))"
            }
        }
    }

    # Replace path parameters
    foreach ($paramName in $pathParams.Keys) {
        $escapedParam = [regex]::Escape("{$paramName}")
        $script += "`$path = `$path -replace '$escapedParam', '$($pathParams[$paramName])'`r`n"
    }

    # Build full URL with query parameters
    if ($queryParams.Count -gt 0) {
        $script += "`$url = `"`$baseUrl`$path?$($queryParams -join '&')`"`r`n"
    }
    else {
        $script += "`$url = `"`$baseUrl`$path`"`r`n"
    }

    $script += "`r`n"

    # Build the Invoke-WebRequest command
    if ($bodyContent) {
        $script += "`$body = @'`r`n"
        $script += $bodyContent
        $script += "`r`n'@`r`n`r`n"
        $script += @"
try {
    `$response = Invoke-WebRequest -Uri `$url -Method $Method -Headers `$headers -Body `$body -ContentType "application/json"
    Write-Host "Success: `$(`$response.StatusCode)"
    `$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
} catch {
    Write-Error "Request failed: `$(`$_.Exception.Message)"
}
"@
    }
    else {
        $script += @"
try {
    `$response = Invoke-WebRequest -Uri `$url -Method $Method -Headers `$headers
    Write-Host "Success: `$(`$response.StatusCode)"
    `$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
} catch {
    Write-Error "Request failed: `$(`$_.Exception.Message)"
}
"@
    }

    return $script
}

function Export-CurlCommand {
    param (
        [string]$Method,
        [string]$Path,
        [hashtable]$Parameters,
        [string]$Token,
        [string]$Region = "mypurecloud.com"
    )

    $baseUrl = "https://api.$Region"
    $fullPath = $Path

    # Build query parameters and handle path parameters
    $queryParams = @()
    $bodyContent = ""

    if ($Parameters) {
        foreach ($paramName in $Parameters.Keys) {
            $paramValue = $Parameters[$paramName]
            if ([string]::IsNullOrWhiteSpace($paramValue)) { continue }

            $pattern = "{$paramName}"
            if ($fullPath -match [regex]::Escape($pattern)) {
                # Path parameter
                $fullPath = $fullPath -replace [regex]::Escape($pattern), $paramValue
            }
            elseif ($paramName -eq "body") {
                # Body parameter
                $bodyContent = $paramValue
            }
            else {
                # Query parameter - escape for URL
                $encodedValue = [System.Uri]::EscapeDataString($paramValue)
                $queryParams += "$paramName=$encodedValue"
            }
        }
    }

    # Build full URL
    $url = "$baseUrl$fullPath"
    if ($queryParams.Count -gt 0) {
        $url += "?" + ($queryParams -join "&")
    }

    # Build cURL command
    $curl = "curl -X $($Method.ToUpper()) `"$url`" ``"
    $curl += "`r`n  -H `"Authorization: Bearer $Token`" ``"
    $curl += "`r`n  -H `"Content-Type: application/json`""

    if ($bodyContent) {
        # Escape body for shell - single quotes are safest for JSON
        $escapedBody = $bodyContent -replace "'", "'\\''"
        $curl += " ``"
        $curl += "`r`n  -d '$escapedBody'"
    }

    return $curl
}

function Populate-ParameterValues {
    param ([Parameter(ValueFromPipeline)] $ParameterSet)

    if (-not $ParameterSet) { return }
    foreach ($entry in $ParameterSet) {
        $name = $entry.name
        if (-not $name) { continue }

        $input = $paramInputs[$name]
        if ($input -and $null -ne $entry.value) {
            Set-ParameterControlValue -Control $input -Value $entry.value
        }
    }
}

function Resolve-SchemaReference {
    param (
        $Schema,
        $Definitions
    )

    if (-not $Schema) {
        return $null
    }

    $current = $Schema
    $depth = 0
    while ($current.'$ref' -and $depth -lt 10) {
        if ($current.'$ref' -match "#/definitions/(.+)") {
            $refName = $Matches[1]
            if ($Definitions -and $Definitions.$refName) {
                $current = $Definitions.$refName
            } else {
                return $current
            }
        } else {
            break
        }
        $depth++
    }

    return $current
}

function Format-SchemaType {
    param (
        $Schema,
        $Definitions
    )

    $resolved = Resolve-SchemaReference -Schema $Schema -Definitions $Definitions
    if (-not $resolved) {
        return "unknown"
    }

    $type = $resolved.type
    if (-not $type -and $resolved.'$ref') {
        $type = "ref"
    }

    if ($type -eq "array" -and $resolved.items) {
        $itemType = Format-SchemaType -Schema $resolved.items -Definitions $Definitions
        return "array of $itemType"
    }

    if ($type) {
        return $type
    }

    return "object"
}

function Flatten-Schema {
    param (
        $Schema,
        $Definitions,
        [string]$Prefix = "",
        [int]$Depth = 0
    )

    if ($Depth -ge 10) {
        return @()
    }

    $resolved = Resolve-SchemaReference -Schema $Schema -Definitions $Definitions
    if (-not $resolved) {
        return @()
    }

    $entries = @()
    $type = $resolved.type

    if ($type -eq "object" -or $resolved.properties) {
        $requiredSet = @{}
        $requiredList = if ($resolved.required) { $resolved.required } else { @() }
        foreach ($req in $requiredList) {
            $requiredSet[$req] = $true
        }

        $props = $resolved.properties
        if ($props) {
            foreach ($prop in $props.PSObject.Properties) {
                $fieldName = if ($Prefix) { "$Prefix.$($prop.Name)" } else { $prop.Name }
                $propResolved = Resolve-SchemaReference -Schema $prop.Value -Definitions $Definitions
                $entries += [PSCustomObject]@{
                    Field       = $fieldName
                    Type        = Format-SchemaType -Schema $prop.Value -Definitions $Definitions
                    Description = $propResolved.description
                    Required    = if ($requiredSet.ContainsKey($prop.Name)) { "Yes" } else { "No" }
                }

                if ($propResolved.type -eq "object" -or $propResolved.type -eq "array" -or $propResolved.'$ref') {
                    $entries += Flatten-Schema -Schema $prop.Value -Definitions $Definitions -Prefix $fieldName -Depth ($Depth + 1)
                }
            }
        }
    }
    elseif ($type -eq "array" -and $resolved.items) {
        $itemField = if ($Prefix) { "$Prefix[]" } else { "[]" }
        $entries += [PSCustomObject]@{
            Field       = $itemField
            Type        = Format-SchemaType -Schema $resolved.items -Definitions $Definitions
            Description = $resolved.items.description
            Required    = "No"
        }

        $entries += Flatten-Schema -Schema $resolved.items -Definitions $Definitions -Prefix $itemField -Depth ($Depth + 1)
    }

    return $entries
}

function Get-ResponseSchema {
    param ($MethodObject)

    if (-not $MethodObject) { return $null }

    $preferredCodes = @("200", "201", "202", "203", "default")
    foreach ($code in $preferredCodes) {
        $resp = $MethodObject.responses.$code
        if ($resp -and $resp.schema) {
            return $resp.schema
        }
    }

    foreach ($resp in $MethodObject.responses.PSObject.Properties) {
        if ($resp.Value -and $resp.Value.schema) {
            return $resp.Value.schema
        }
    }

    return $null
}

function Update-SchemaList {
    param ($Schema)

    if (-not $schemaList) { return }
    $schemaList.Items.Clear()

    $entries = Flatten-Schema -Schema $Schema -Definitions $Definitions
    if (-not $entries -or $entries.Count -eq 0) {
        $entries = @([PSCustomObject]@{
            Field       = "(no schema available)"
            Type        = ""
            Description = ""
            Required    = ""
        })
    }

    foreach ($entry in $entries) {
        $schemaList.Items.Add($entry) | Out-Null
    }
}

# Script-level variables to track tree population progress
$script:InspectorNodeCount = 0
$script:InspectorMaxNodes = 2000
$script:InspectorMaxDepth = 15

# Maximum length for log message truncation
$script:LogMaxMessageLength = 500

function Populate-InspectorTree {
    param (
        $Tree,
        $Data,
        [string]$Label = "root",
        [int]$Depth = 0
    )

    if (-not $Tree) { return }

    # Check if we've exceeded the maximum node count to prevent freezing
    if ($script:InspectorNodeCount -ge $script:InspectorMaxNodes) {
        if ($Depth -eq 0) {
            $limitNode = New-Object System.Windows.Controls.TreeViewItem
            $limitNode.Header = "[Maximum node limit reached ($($script:InspectorMaxNodes) nodes). Use Raw tab for full data.]"
            $limitNode.Foreground = [System.Windows.Media.Brushes]::OrangeRed
            $Tree.Items.Add($limitNode) | Out-Null
        }
        return
    }

    # Check if we've exceeded the maximum depth to prevent deep recursion
    if ($Depth -ge $script:InspectorMaxDepth) {
        $depthNode = New-Object System.Windows.Controls.TreeViewItem
        $depthNode.Header = "[Max depth reached - use Raw tab for full data]"
        $depthNode.Foreground = [System.Windows.Media.Brushes]::Gray
        $Tree.Items.Add($depthNode) | Out-Null
        return
    }

    $script:InspectorNodeCount++
    $node = New-Object System.Windows.Controls.TreeViewItem
    $isEnumerable = ($Data -is [System.Collections.IEnumerable]) -and -not ($Data -is [string])
    if ($Data -and $Data.PSObject.Properties.Count -gt 0) {
        $node.Header = "$($Label) (object)"
        foreach ($prop in $Data.PSObject.Properties) {
            if ($script:InspectorNodeCount -ge $script:InspectorMaxNodes) {
                $ellipsis = New-Object System.Windows.Controls.TreeViewItem
                $ellipsis.Header = "[... node limit reached]"
                $ellipsis.Foreground = [System.Windows.Media.Brushes]::Gray
                $node.Items.Add($ellipsis) | Out-Null
                break
            }
            Populate-InspectorTree -Tree $node -Data $prop.Value -Label "$($prop.Name)" -Depth ($Depth + 1)
        }
    }
    elseif ($isEnumerable) {
        $node.Header = "$($Label) (array)"
        $count = 0
        foreach ($item in $Data) {
            if ($count -ge 150) {
                $ellipsis = New-Object System.Windows.Controls.TreeViewItem
                $ellipsis.Header = "[... $($Data.Count - 150) more items]"
                $ellipsis.Foreground = [System.Windows.Media.Brushes]::Gray
                $node.Items.Add($ellipsis) | Out-Null
                break
            }
            if ($script:InspectorNodeCount -ge $script:InspectorMaxNodes) {
                $ellipsis = New-Object System.Windows.Controls.TreeViewItem
                $ellipsis.Header = "[... node limit reached]"
                $ellipsis.Foreground = [System.Windows.Media.Brushes]::Gray
                $node.Items.Add($ellipsis) | Out-Null
                break
            }

            Populate-InspectorTree -Tree $node -Data $item -Label "[$count]" -Depth ($Depth + 1)
            $count++
        }
    }
    else {
        $valueText = if ($Data -ne $null) { $Data.ToString() } else { "<null>" }
        $node.Header = "$($Label): $valueText"
    }

    $node.IsExpanded = $Depth -lt 2
    $Tree.Items.Add($node) | Out-Null
}

function Show-DataInspector {
    param ([string]$JsonText)

    $sourceText = $JsonText
    if (-not $sourceText -and $script:LastResponseFile -and (Test-Path -Path $script:LastResponseFile)) {
        $fileInfo = Get-Item -Path $script:LastResponseFile
        if ($fileInfo.Length -gt 5MB) {
            $result = [System.Windows.MessageBox]::Show("The stored result is large ($([math]::Round($fileInfo.Length / 1MB, 1)) MB). Parsing it may take some time. Continue?", "Large Result Warning", "YesNo")
            if ($result -ne "Yes") {
                Add-LogEntry "Inspector aborted by user for large stored result."
                return
            }
        }
        $sourceText = Get-Content -Path $script:LastResponseFile -Raw
    }

    if (-not $sourceText) {
        Add-LogEntry "Inspector: no data to show."
        return
    }

    try {
        $parsed = $sourceText | ConvertFrom-Json -ErrorAction Stop
    } catch {
        [System.Windows.MessageBox]::Show("Unable to parse current response for inspection.`n$($_.Exception.Message)", "Data Inspector")
        return
    }

    $inspectorXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Data Inspector" Height="600" Width="700" WindowStartupLocation="CenterOwner">
  <DockPanel Margin="10">
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 0 0 8">
      <Button Name="CopyJsonButton" Width="110" Height="28" Content="Copy JSON" Margin="0 0 10 0"/>
      <Button Name="ExportJsonButton" Width="130" Height="28" Content="Export JSON"/>
    </StackPanel>
    <TabControl>
      <TabItem Header="Structured">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <TreeView Name="InspectorTree"/>
        </ScrollViewer>
      </TabItem>
      <TabItem Header="Raw">
        <TextBox Name="InspectorRaw" TextWrapping="Wrap" AcceptsReturn="True"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" IsReadOnly="True"/>
      </TabItem>
    </TabControl>
  </DockPanel>
</Window>
"@

    $inspectorWindow = [System.Windows.Markup.XamlReader]::Parse($inspectorXaml)
    if (-not $inspectorWindow) {
        Add-LogEntry "Data Inspector UI failed to load."
        return
    }

    $treeView = $inspectorWindow.FindName("InspectorTree")
    $rawBox = $inspectorWindow.FindName("InspectorRaw")
    $copyButton = $inspectorWindow.FindName("CopyJsonButton")
    $exportButton = $inspectorWindow.FindName("ExportJsonButton")

    if ($rawBox) {
        $rawBox.Text = $sourceText
    }

    if ($treeView) {
        $treeView.Items.Clear()
        # Reset the node counter before populating
        $script:InspectorNodeCount = 0
        Add-LogEntry "Inspector: Building tree view for data (max $($script:InspectorMaxNodes) nodes, max depth $($script:InspectorMaxDepth))..."
        Populate-InspectorTree -Tree $treeView -Data $parsed -Label "root"
        Add-LogEntry "Inspector: Tree view populated with $($script:InspectorNodeCount) nodes."
    }

    if ($copyButton) {
        $copyButton.Add_Click({
            if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                Set-Clipboard -Value $sourceText
                Add-LogEntry "Raw JSON copied to clipboard via inspector."
            } else {
                [System.Windows.MessageBox]::Show("Clipboard access is not available in this host.", "Clipboard")
                Add-LogEntry "Clipboard copy skipped (command missing)."
            }
        })
    }

    if ($exportButton) {
        $exportButton.Add_Click({
            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
            $dialog.FileName = "GenesysData.json"
            $dialog.Title = "Export Inspector JSON"
            if ($dialog.ShowDialog() -eq $true) {
                $JsonText | Out-File -FilePath $dialog.FileName -Encoding utf8
                Add-LogEntry "Inspector JSON exported to $($dialog.FileName)"
            }
        })
    }

    if ($Window) {
        $inspectorWindow.Owner = $Window
    }
    $inspectorWindow.ShowDialog() | Out-Null
}

function Job-StatusIsPending {
    param ([string]$Status)

    if (-not $Status) { return $false }
    return $Status -match '^(pending|running|in[-]?progress|processing|created)$'
}

function Get-ConversationReport {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConversationId,
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,
        [string]$BaseUrl = "https://api.usw2.pure.cloud"
    )

    $result = [PSCustomObject]@{
        ConversationId      = $ConversationId
        ConversationDetails = $null
        AnalyticsDetails    = $null
        RetrievedAt         = (Get-Date).ToString("o")
        Errors              = @()
    }

    # Fetch conversation details
    $conversationUrl = "$BaseUrl/conversations/$ConversationId"
    try {
        $conversationResponse = Invoke-WebRequest -Uri $conversationUrl -Method Get -Headers $Headers -ErrorAction Stop
        $result.ConversationDetails = $conversationResponse.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
    }
    catch {
        $result.Errors += "Conversation details: $($_.Exception.Message)"
    }

    # Fetch analytics details
    $analyticsUrl = "$BaseUrl/analytics/conversations/$ConversationId/details"
    try {
        $analyticsResponse = Invoke-WebRequest -Uri $analyticsUrl -Method Get -Headers $Headers -ErrorAction Stop
        $result.AnalyticsDetails = $analyticsResponse.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
    }
    catch {
        $result.Errors += "Analytics details: $($_.Exception.Message)"
    }

    return $result
}

<#
.SYNOPSIS
    Extracts timeline events from analytics and conversation details.
.DESCRIPTION
    Parses both API responses and creates a unified list of events with timestamps,
    participant info, segment IDs, MOS scores, error codes, and event types.
#>
function Get-GCConversationDetailsTimeline {
    param (
        [Parameter(Mandatory = $true)]
        $Report
    )

    # Use ArrayList for efficient appending instead of array += which creates new arrays
    $events = [System.Collections.ArrayList]::new()
    $segmentCounter = 0

    # Extract events from analytics details (segments with MOS, errorCodes, etc.)
    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.participants) {
        foreach ($participant in $Report.AnalyticsDetails.participants) {
            $participantName = if ($participant.participantName) { $participant.participantName } else { $participant.purpose }
            $participantId = $participant.participantId

            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    $mediaType = $session.mediaType
                    $direction = $session.direction
                    $ani = $session.ani
                    $dnis = $session.dnis
                    $sessionId = $session.sessionId

                    if ($session.segments) {
                        foreach ($segment in $session.segments) {
                            $segmentCounter++
                            $segmentId = $segmentCounter
                            $segmentType = $segment.segmentType
                            $queueId = $segment.queueId
                            $flowId = $segment.flowId
                            $flowName = $segment.flowName
                            $queueName = $segment.queueName
                            $wrapUpCode = $segment.wrapUpCode
                            $wrapUpNote = $segment.wrapUpNote

                            # Extract MOS and error codes from metrics
                            # Use specific MOS metric names to avoid false matches
                            $mos = $null
                            $errorCode = $null
                            if ($segment.metrics) {
                                foreach ($metric in $segment.metrics) {
                                    if ($metric.name -eq "nMos" -or $metric.name -eq "mos" -or $metric.name -eq "MOS") {
                                        $mos = $metric.value
                                    }
                                }
                            }
                            if ($segment.errorCode) {
                                $errorCode = $segment.errorCode
                            }
                            # Also check for sipResponseCode as an error indicator
                            if ($segment.sipResponseCode -and -not $errorCode) {
                                $errorCode = "sip:$($segment.sipResponseCode)"
                            }

                            # Segment start event - parse with InvariantCulture for reliable ISO 8601 parsing
                            if ($segment.segmentStart) {
                                [void]$events.Add([PSCustomObject]@{
                                    Timestamp    = [DateTime]::Parse($segment.segmentStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                    Source       = "AnalyticsDetails"
                                    Participant  = $participantName
                                    ParticipantId = $participantId
                                    SegmentId    = $segmentId
                                    EventType    = "SegmentStart"
                                    SegmentType  = $segmentType
                                    MediaType    = $mediaType
                                    Direction    = $direction
                                    QueueName    = $queueName
                                    FlowName     = $flowName
                                    Mos          = $null
                                    ErrorCode    = $null
                                    Context      = "ANI: $ani, DNIS: $dnis"
                                    DisconnectType = $null
                                })
                            }

                            # Segment end event - parse with InvariantCulture
                            if ($segment.segmentEnd) {
                                $disconnectType = $segment.disconnectType
                                [void]$events.Add([PSCustomObject]@{
                                    Timestamp    = [DateTime]::Parse($segment.segmentEnd, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                    Source       = "AnalyticsDetails"
                                    Participant  = $participantName
                                    ParticipantId = $participantId
                                    SegmentId    = $segmentId
                                    EventType    = if ($disconnectType) { "Disconnect" } else { "SegmentEnd" }
                                    SegmentType  = $segmentType
                                    MediaType    = $mediaType
                                    Direction    = $direction
                                    QueueName    = $queueName
                                    FlowName     = $flowName
                                    Mos          = $mos
                                    ErrorCode    = $errorCode
                                    Context      = if ($disconnectType) { "DisconnectType: $disconnectType" } else { $null }
                                    DisconnectType = $disconnectType
                                })
                            }
                        }
                    }
                }
            }
        }
    }

    # Extract events from conversation details (state transitions, etc.)
    if ($Report.ConversationDetails -and $Report.ConversationDetails.participants) {
        foreach ($participant in $Report.ConversationDetails.participants) {
            $participantName = if ($participant.name) { $participant.name } else { $participant.purpose }
            $participantId = $participant.id

            # Start time event - parse with InvariantCulture
            if ($participant.startTime) {
                [void]$events.Add([PSCustomObject]@{
                    Timestamp    = [DateTime]::Parse($participant.startTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                    Source       = "Conversations"
                    Participant  = $participantName
                    ParticipantId = $participantId
                    SegmentId    = $null
                    EventType    = "ParticipantJoined"
                    SegmentType  = $null
                    MediaType    = $null
                    Direction    = $null
                    QueueName    = $null
                    FlowName     = $null
                    Mos          = $null
                    ErrorCode    = $null
                    Context      = "Purpose: $($participant.purpose)"
                    DisconnectType = $null
                })
            }

            # End time / disconnect event - parse with InvariantCulture
            if ($participant.endTime) {
                $disconnectType = $participant.disconnectType
                [void]$events.Add([PSCustomObject]@{
                    Timestamp    = [DateTime]::Parse($participant.endTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                    Source       = "Conversations"
                    Participant  = $participantName
                    ParticipantId = $participantId
                    SegmentId    = $null
                    EventType    = if ($disconnectType) { "Disconnect" } else { "ParticipantLeft" }
                    SegmentType  = $null
                    MediaType    = $null
                    Direction    = $null
                    QueueName    = $null
                    FlowName     = $null
                    Mos          = $null
                    ErrorCode    = $null
                    Context      = if ($disconnectType) { "DisconnectType: $disconnectType" } else { $null }
                    DisconnectType = $disconnectType
                })
            }

            # Process calls/chats for state changes
            if ($participant.calls) {
                foreach ($call in $participant.calls) {
                    if ($call.state -and $call.connectedTime) {
                        [void]$events.Add([PSCustomObject]@{
                            Timestamp    = [DateTime]::Parse($call.connectedTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                            Source       = "Conversations"
                            Participant  = $participantName
                            ParticipantId = $participantId
                            SegmentId    = $null
                            EventType    = "StateChange"
                            SegmentType  = $null
                            MediaType    = "voice"
                            Direction    = $call.direction
                            QueueName    = $null
                            FlowName     = $null
                            Mos          = $null
                            ErrorCode    = $null
                            Context      = "State: connected"
                            DisconnectType = $null
                        })
                    }
                    if ($call.disconnectedTime) {
                        [void]$events.Add([PSCustomObject]@{
                            Timestamp    = [DateTime]::Parse($call.disconnectedTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                            Source       = "Conversations"
                            Participant  = $participantName
                            ParticipantId = $participantId
                            SegmentId    = $null
                            EventType    = "Disconnect"
                            SegmentType  = $null
                            MediaType    = "voice"
                            Direction    = $call.direction
                            QueueName    = $null
                            FlowName     = $null
                            Mos          = $null
                            ErrorCode    = $null
                            Context      = "State: disconnected"
                            DisconnectType = $call.disconnectType
                        })
                    }
                }
            }

            # Process chats
            if ($participant.chats) {
                foreach ($chat in $participant.chats) {
                    if ($chat.state -and $chat.connectedTime) {
                        [void]$events.Add([PSCustomObject]@{
                            Timestamp    = [DateTime]::Parse($chat.connectedTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                            Source       = "Conversations"
                            Participant  = $participantName
                            ParticipantId = $participantId
                            SegmentId    = $null
                            EventType    = "StateChange"
                            SegmentType  = $null
                            MediaType    = "chat"
                            Direction    = $chat.direction
                            QueueName    = $null
                            FlowName     = $null
                            Mos          = $null
                            ErrorCode    = $null
                            Context      = "State: connected"
                            DisconnectType = $null
                        })
                    }
                    if ($chat.disconnectedTime) {
                        [void]$events.Add([PSCustomObject]@{
                            Timestamp    = [DateTime]::Parse($chat.disconnectedTime, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                            Source       = "Conversations"
                            Participant  = $participantName
                            ParticipantId = $participantId
                            SegmentId    = $null
                            EventType    = "Disconnect"
                            SegmentType  = $null
                            MediaType    = "chat"
                            Direction    = $chat.direction
                            QueueName    = $null
                            FlowName     = $null
                            Mos          = $null
                            ErrorCode    = $null
                            Context      = "State: disconnected"
                            DisconnectType = $chat.disconnectType
                        })
                    }
                }
            }
        }
    }

    return $events
}

<#
.SYNOPSIS
    Merges and sorts conversation events chronologically.
.DESCRIPTION
    Takes events from Get-GCConversationDetailsTimeline and sorts them by timestamp
    to create a unified, chronological view of the conversation.
#>
function Merge-GCConversationEvents {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Events
    )

    # Sort events by timestamp ascending
    $sortedEvents = $Events | Sort-Object -Property Timestamp

    return $sortedEvents
}

<#
.SYNOPSIS
    Formats the chronological timeline as text output.
.DESCRIPTION
    Creates a text-based timeline with each event on a line showing timestamp,
    event type, participant, segment ID, MOS score, and error code.
#>
function Format-GCConversationTimelineText {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Events
    )

    $sb = [System.Text.StringBuilder]::new()

    foreach ($event in $Events) {
        # Format timestamp in UTC with proper ISO 8601 format
        $timestamp = $event.Timestamp.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")
        $eventType = $event.EventType.PadRight(18)

        # Build participant/context string
        $participantStr = ""
        if ($event.FlowName) {
            $participantStr = "Flow: $($event.FlowName)"
        } elseif ($event.QueueName) {
            $participantStr = "Queue: $($event.QueueName)"
        } elseif ($event.Participant) {
            $participantStr = $event.Participant
        } else {
            $participantStr = "(unknown)"
        }

        # Build segment string
        $segmentStr = if ($event.SegmentId) { "seg=$($event.SegmentId)" } else { "" }

        # Build media/direction string
        $mediaStr = ""
        if ($event.MediaType -or $event.Direction) {
            $parts = @()
            if ($event.MediaType) { $parts += "media=$($event.MediaType)" }
            if ($event.Direction) { $parts += "dir=$($event.Direction)" }
            $mediaStr = $parts -join " | "
        }

        # Build MOS string with degraded marker - use TryParse for safe conversion
        $mosStr = ""
        if ($null -ne $event.Mos) {
            $mosValue = 0.0
            if ([double]::TryParse($event.Mos.ToString(), [ref]$mosValue)) {
                if ($mosValue -lt 3.5) {
                    $mosStr = "MOS=$($mosValue.ToString('0.00')) (DEGRADED)"
                } else {
                    $mosStr = "MOS=$($mosValue.ToString('0.00'))"
                }
            }
        }

        # Build error code string
        $errorStr = if ($event.ErrorCode) { "errorCode=$($event.ErrorCode)" } else { "" }

        # Build disconnect info
        $disconnectStr = ""
        if ($event.EventType -eq "Disconnect" -and $event.DisconnectType) {
            $disconnectStr = "$($event.Participant) disconnected ($($event.DisconnectType))"
        }

        # Construct the line
        $lineParts = @($timestamp, "|", $eventType, "|", $participantStr)
        if ($segmentStr) { $lineParts += "| $segmentStr" }
        if ($mediaStr) { $lineParts += "| $mediaStr" }
        if ($mosStr) { $lineParts += "| $mosStr" }
        if ($errorStr) { $lineParts += "| $errorStr" }
        if ($disconnectStr) { $lineParts += "| $disconnectStr" }

        $line = $lineParts -join " "
        [void]$sb.AppendLine($line.Trim())
    }

    return $sb.ToString()
}

<#
.SYNOPSIS
    Generates a summary of degraded segments and disconnects.
.DESCRIPTION
    Analyzes the timeline events to produce summary statistics including
    total segments, segments with MOS values, degraded segments (MOS < 3.5),
    and all disconnect events.
#>
function Get-GCConversationSummary {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConversationId,
        [Parameter(Mandatory = $true)]
        [array]$Events
    )

    # Count segments (SegmentEnd events contain the final MOS)
    $segmentEndEvents = $Events | Where-Object { $_.EventType -eq "SegmentEnd" -or ($_.EventType -eq "Disconnect" -and $_.SegmentId) }
    $segmentStartEvents = $Events | Where-Object { $_.EventType -eq "SegmentStart" }

    $totalSegments = ($segmentStartEvents | Measure-Object).Count

    # Get segments with MOS values
    $segmentsWithMos = $segmentEndEvents | Where-Object { $null -ne $_.Mos }
    $segmentsWithMosCount = ($segmentsWithMos | Measure-Object).Count

    # Get degraded segments (MOS < 3.5) - use TryParse for safe conversion
    $degradedSegments = $segmentsWithMos | Where-Object {
        $mosValue = 0.0
        if ([double]::TryParse($_.Mos.ToString(), [ref]$mosValue)) {
            return $mosValue -lt 3.5
        }
        return $false
    }
    $degradedCount = ($degradedSegments | Measure-Object).Count

    # Get all disconnect events
    $disconnectEvents = $Events | Where-Object { $_.EventType -eq "Disconnect" }

    # Build segment details lookup (start times)
    $segmentDetails = @{}
    foreach ($startEvent in $segmentStartEvents) {
        if ($startEvent.SegmentId) {
            $segmentDetails[$startEvent.SegmentId] = $startEvent
        }
    }

    return [PSCustomObject]@{
        ConversationId       = $ConversationId
        TotalSegments        = $totalSegments
        SegmentsWithMos      = $segmentsWithMosCount
        DegradedSegmentCount = $degradedCount
        DegradedSegments     = $degradedSegments
        DisconnectEvents     = $disconnectEvents
        SegmentDetails       = $segmentDetails
    }
}

<#
.SYNOPSIS
    Formats the conversation summary as text output.
.DESCRIPTION
    Creates a text block with summary statistics and lists of degraded
    segments and disconnect events.
#>
function Format-GCConversationSummaryText {
    param (
        [Parameter(Mandatory = $true)]
        $Summary
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("=" * 50 + " Summary " + "=" * 50)
    [void]$sb.AppendLine("ConversationId: $($Summary.ConversationId)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Segments:          $($Summary.TotalSegments)")
    [void]$sb.AppendLine("Segments with MOS: $($Summary.SegmentsWithMos)")
    [void]$sb.AppendLine("Degraded segments (MOS < 3.5): $($Summary.DegradedSegmentCount)")
    [void]$sb.AppendLine("")

    # List degraded segments
    if ($Summary.DegradedSegments -and ($Summary.DegradedSegments | Measure-Object).Count -gt 0) {
        [void]$sb.AppendLine("Degraded segments:")
        foreach ($seg in $Summary.DegradedSegments) {
            $startInfo = $Summary.SegmentDetails[$seg.SegmentId]
            $startTime = if ($startInfo) { $startInfo.Timestamp.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK") } else { "(unknown)" }
            $endTime = $seg.Timestamp.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")

            $participantStr = if ($seg.QueueName) { "Queue: $($seg.QueueName)" } `
                              elseif ($seg.FlowName) { "Flow: $($seg.FlowName)" } `
                              elseif ($seg.Participant) { $seg.Participant } `
                              else { "(unknown)" }

            # Use TryParse for safe MOS value conversion
            $mosValue = 0.0
            [void][double]::TryParse($seg.Mos.ToString(), [ref]$mosValue)
            $errorStr = if ($seg.ErrorCode) { "errorCode=$($seg.ErrorCode)" } else { "errorCode=" }

            [void]$sb.AppendLine("  - seg=$($seg.SegmentId) | $participantStr | MOS=$($mosValue.ToString('0.00')) | $startTime-$endTime | $errorStr")
        }
        [void]$sb.AppendLine("")
    }

    # List disconnect events
    if ($Summary.DisconnectEvents -and ($Summary.DisconnectEvents | Measure-Object).Count -gt 0) {
        [void]$sb.AppendLine("Disconnects:")
        foreach ($disc in $Summary.DisconnectEvents) {
            $timestamp = $disc.Timestamp.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")
            $segStr = if ($disc.SegmentId) { "seg=$($disc.SegmentId)" } else { "(no segment)" }
            $disconnector = if ($disc.DisconnectType) { "$($disc.Participant) disconnected ($($disc.DisconnectType))" } else { "$($disc.Participant) disconnected" }
            $errorStr = if ($disc.ErrorCode) { "errorCode=$($disc.ErrorCode)" } else { "errorCode=" }

            [void]$sb.AppendLine("  - $timestamp | $segStr | $disconnector | $errorStr")
        }
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("=" * 109)

    return $sb.ToString()
}

<#
.SYNOPSIS
    Calculates duration statistics from conversation events and analytics data.
.DESCRIPTION
    Computes total duration, IVR time, queue wait time, agent talk time, hold time,
    wrap-up time, and other timing metrics from the conversation data.
#>
function Get-GCConversationDurationAnalysis {
    param (
        [Parameter(Mandatory = $true)]
        $Report,
        [Parameter(Mandatory = $true)]
        [array]$Events
    )

    $analysis = [PSCustomObject]@{
        TotalDurationSeconds = 0
        IvrTimeSeconds       = 0
        QueueWaitSeconds     = 0
        AgentTalkSeconds     = 0
        HoldTimeSeconds      = 0
        WrapUpSeconds        = 0
        ConferenceSeconds    = 0
        SystemTimeSeconds    = 0
        InteractTimeSeconds  = 0
        AlertTimeSeconds     = 0
        ConversationStart    = $null
        ConversationEnd      = $null
        SegmentBreakdown     = @{}
    }

    # Get conversation start/end times from analytics or conversation details
    if ($Report.AnalyticsDetails) {
        if ($Report.AnalyticsDetails.conversationStart) {
            $analysis.ConversationStart = [DateTime]::Parse($Report.AnalyticsDetails.conversationStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        }
        if ($Report.AnalyticsDetails.conversationEnd) {
            $analysis.ConversationEnd = [DateTime]::Parse($Report.AnalyticsDetails.conversationEnd, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        }
    }

    # Calculate total duration
    if ($analysis.ConversationStart -and $analysis.ConversationEnd) {
        $analysis.TotalDurationSeconds = ($analysis.ConversationEnd - $analysis.ConversationStart).TotalSeconds
    }

    # Process segments from analytics to extract timing metrics
    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.participants) {
        foreach ($participant in $Report.AnalyticsDetails.participants) {
            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    # Extract metrics from session if available
                    if ($session.metrics) {
                        foreach ($metric in $session.metrics) {
                            # Metrics are typically in milliseconds
                            $valueSeconds = if ($metric.value) { $metric.value / 1000.0 } else { 0 }
                            # Note: "Complete" metrics are cumulative totals; regular metrics may be emitted multiple times
                            # For talk/held, we use the "Complete" values when available as they represent totals
                            switch ($metric.name) {
                                "tIvr" { $analysis.IvrTimeSeconds += $valueSeconds }
                                "tAcd" { $analysis.QueueWaitSeconds += $valueSeconds }
                                "tTalk" {
                                    # Regular tTalk may be emitted multiple times; track the max as a fallback
                                    $analysis.AgentTalkSeconds = [Math]::Max($analysis.AgentTalkSeconds, $valueSeconds)
                                }
                                "tTalkComplete" {
                                    # Complete value is the authoritative total
                                    $analysis.AgentTalkSeconds = [Math]::Max($analysis.AgentTalkSeconds, $valueSeconds)
                                }
                                "tHeld" {
                                    # Regular tHeld may be emitted multiple times; track the max as a fallback
                                    $analysis.HoldTimeSeconds = [Math]::Max($analysis.HoldTimeSeconds, $valueSeconds)
                                }
                                "tHeldComplete" {
                                    # Complete value is the authoritative total
                                    $analysis.HoldTimeSeconds = [Math]::Max($analysis.HoldTimeSeconds, $valueSeconds)
                                }
                                "tAcw" { $analysis.WrapUpSeconds += $valueSeconds }
                                "tAlert" { $analysis.AlertTimeSeconds += $valueSeconds }
                            }
                        }
                    }

                    # Calculate segment-based timing
                    if ($session.segments) {
                        foreach ($segment in $session.segments) {
                            if ($segment.segmentStart -and $segment.segmentEnd) {
                                $start = [DateTime]::Parse($segment.segmentStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                $end = [DateTime]::Parse($segment.segmentEnd, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                $durationSec = ($end - $start).TotalSeconds

                                $segType = if ($segment.segmentType) { $segment.segmentType } else { "unknown" }
                                if (-not $analysis.SegmentBreakdown.ContainsKey($segType)) {
                                    $analysis.SegmentBreakdown[$segType] = 0
                                }
                                $analysis.SegmentBreakdown[$segType] += $durationSec

                                switch ($segType) {
                                    "interact" { $analysis.InteractTimeSeconds += $durationSec }
                                    "hold" { $analysis.HoldTimeSeconds += $durationSec }
                                    "system" { $analysis.SystemTimeSeconds += $durationSec }
                                    "ivr" { $analysis.IvrTimeSeconds += $durationSec }
                                    "wrapup" { $analysis.WrapUpSeconds += $durationSec }
                                    "alert" { $analysis.AlertTimeSeconds += $durationSec }
                                }

                                if ($segment.conference -eq $true) {
                                    $analysis.ConferenceSeconds += $durationSec
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return $analysis
}

<#
.SYNOPSIS
    Generates participant statistics from conversation data.
.DESCRIPTION
    Calculates per-participant metrics including time in conversation,
    segment counts, and role-specific information.
#>
function Get-GCParticipantStatistics {
    param (
        [Parameter(Mandatory = $true)]
        $Report
    )

    $stats = [System.Collections.ArrayList]::new()

    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.participants) {
        foreach ($participant in $Report.AnalyticsDetails.participants) {
            $participantName = if ($participant.participantName) { $participant.participantName } else { $participant.purpose }
            $purpose = $participant.purpose

            $participantStat = [PSCustomObject]@{
                Name           = $participantName
                ParticipantId  = $participant.participantId
                Purpose        = $purpose
                SessionCount   = 0
                SegmentCount   = 0
                TotalDurationSeconds = 0
                MediaTypes     = [System.Collections.ArrayList]::new()
                DisconnectType = $null
                HasErrors      = $false
                ErrorCodes     = [System.Collections.ArrayList]::new()
                MosScores      = [System.Collections.ArrayList]::new()
                FlowNames      = [System.Collections.ArrayList]::new()
                QueueNames     = [System.Collections.ArrayList]::new()
                HasRecording   = $false
                Providers      = [System.Collections.ArrayList]::new()
                RemoteName     = $null
                ANI            = $null
                DNIS           = $null
            }

            if ($participant.sessions) {
                $participantStat.SessionCount = $participant.sessions.Count

                foreach ($session in $participant.sessions) {
                    if ($session.mediaType -and $participantStat.MediaTypes -notcontains $session.mediaType) {
                        [void]$participantStat.MediaTypes.Add($session.mediaType)
                    }

                    # Extract recording info
                    if ($session.recording -eq $true) {
                        $participantStat.HasRecording = $true
                    }

                    # Extract provider info
                    if ($session.provider -and $participantStat.Providers -notcontains $session.provider) {
                        [void]$participantStat.Providers.Add($session.provider)
                    }

                    # Extract remote party name
                    if ($session.remoteNameDisplayable -and -not $participantStat.RemoteName) {
                        $participantStat.RemoteName = $session.remoteNameDisplayable
                    }

                    # Extract ANI/DNIS
                    if ($session.ani -and -not $participantStat.ANI) {
                        $participantStat.ANI = $session.ani
                    }
                    if ($session.dnis -and -not $participantStat.DNIS) {
                        $participantStat.DNIS = $session.dnis
                    }

                    # Extract flow info
                    if ($session.flow -and $session.flow.flowName) {
                        if ($participantStat.FlowNames -notcontains $session.flow.flowName) {
                            [void]$participantStat.FlowNames.Add($session.flow.flowName)
                        }
                    }

                    if ($session.segments) {
                        $participantStat.SegmentCount += $session.segments.Count

                        foreach ($segment in $session.segments) {
                            # Calculate segment duration
                            if ($segment.segmentStart -and $segment.segmentEnd) {
                                $start = [DateTime]::Parse($segment.segmentStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                $end = [DateTime]::Parse($segment.segmentEnd, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                $participantStat.TotalDurationSeconds += ($end - $start).TotalSeconds
                            }

                            # Track disconnect type
                            if ($segment.disconnectType -and -not $participantStat.DisconnectType) {
                                $participantStat.DisconnectType = $segment.disconnectType
                            }

                            # Track errors
                            if ($segment.errorCode) {
                                $participantStat.HasErrors = $true
                                if ($participantStat.ErrorCodes -notcontains $segment.errorCode) {
                                    [void]$participantStat.ErrorCodes.Add($segment.errorCode)
                                }
                            }

                            # Track queue names
                            if ($segment.queueId) {
                                # Note: queueId would need lookup for actual name
                                if ($participantStat.QueueNames -notcontains $segment.queueId) {
                                    [void]$participantStat.QueueNames.Add($segment.queueId)
                                }
                            }
                        }
                    }

                    # Track MOS from media endpoint stats
                    if ($session.mediaEndpointStats) {
                        foreach ($stat in $session.mediaEndpointStats) {
                            if ($stat.minMos) {
                                [void]$participantStat.MosScores.Add($stat.minMos)
                            }
                        }
                    }
                }
            }

            [void]$stats.Add($participantStat)
        }
    }

    return $stats
}

<#
.SYNOPSIS
    Analyzes the conversation flow and path.
.DESCRIPTION
    Creates a visual representation of the conversation path showing
    how the call moved between IVR, queues, agents, and external parties.
#>
function Get-GCConversationFlowPath {
    param (
        [Parameter(Mandatory = $true)]
        $Report
    )

    $flowPath = [System.Collections.ArrayList]::new()

    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.participants) {
        # Sort participants by their first segment start time
        $participantOrder = @()
        foreach ($participant in $Report.AnalyticsDetails.participants) {
            $earliestTime = $null
            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    if ($session.segments) {
                        foreach ($segment in $session.segments) {
                            if ($segment.segmentStart) {
                                $segTime = [DateTime]::Parse($segment.segmentStart, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
                                if (-not $earliestTime -or $segTime -lt $earliestTime) {
                                    $earliestTime = $segTime
                                }
                            }
                        }
                    }
                }
            }
            $participantOrder += [PSCustomObject]@{
                Participant = $participant
                StartTime   = $earliestTime
            }
        }

        $sortedParticipants = $participantOrder | Sort-Object -Property StartTime

        foreach ($entry in $sortedParticipants) {
            $participant = $entry.Participant
            $participantName = if ($participant.participantName) { $participant.participantName } else { $participant.purpose }
            $purpose = $participant.purpose

            $flowStep = [PSCustomObject]@{
                Order        = $flowPath.Count + 1
                Name         = $participantName
                Purpose      = $purpose
                StartTime    = $entry.StartTime
                FlowName     = $null
                TransferType = $null
                TransferTo   = $null
            }

            # Get flow info and transfer details
            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    if ($session.flow) {
                        $flowStep.FlowName = $session.flow.flowName
                        $flowStep.TransferType = $session.flow.transferType
                        $flowStep.TransferTo = $session.flow.transferTargetName
                    }
                }
            }

            [void]$flowPath.Add($flowStep)
        }
    }

    return $flowPath
}

<#
.SYNOPSIS
    Generates key insights from the conversation analysis.
.DESCRIPTION
    Analyzes all conversation data to produce actionable insights and
    highlights about quality issues, timing anomalies, and patterns.
#>
function Get-GCConversationKeyInsights {
    param (
        [Parameter(Mandatory = $true)]
        $Report,
        [Parameter(Mandatory = $true)]
        $DurationAnalysis,
        [Parameter(Mandatory = $true)]
        $ParticipantStats,
        [Parameter(Mandatory = $true)]
        $Summary
    )

    $insights = [System.Collections.ArrayList]::new()

    # Insight: Overall quality assessment
    $minMos = $null
    if ($Report.AnalyticsDetails -and $Report.AnalyticsDetails.mediaStatsMinConversationMos) {
        $minMos = $Report.AnalyticsDetails.mediaStatsMinConversationMos
        if ($minMos -lt 3.0) {
            [void]$insights.Add([PSCustomObject]@{
                Category = "CRITICAL"
                Type     = "Quality"
                Message  = "Very poor voice quality detected (MOS: $([Math]::Round($minMos, 2))). Call likely had significant audio issues."
            })
        }
        elseif ($minMos -lt 3.5) {
            [void]$insights.Add([PSCustomObject]@{
                Category = "WARNING"
                Type     = "Quality"
                Message  = "Below-average voice quality detected (MOS: $([Math]::Round($minMos, 2))). Some audio degradation may have occurred."
            })
        }
        elseif ($minMos -ge 4.0) {
            [void]$insights.Add([PSCustomObject]@{
                Category = "OK"
                Type     = "Quality"
                Message  = "Good voice quality maintained throughout (MOS: $([Math]::Round($minMos, 2)))."
            })
        }
    }

    # Insight: Long hold times
    if ($DurationAnalysis.HoldTimeSeconds -gt 300) {
        [void]$insights.Add([PSCustomObject]@{
            Category = "WARNING"
            Type     = "Experience"
            Message  = "Extended hold time detected ($([Math]::Round($DurationAnalysis.HoldTimeSeconds / 60, 1)) minutes). Customer may have experienced frustration."
        })
    }

    # Insight: Long IVR time
    if ($DurationAnalysis.IvrTimeSeconds -gt 180) {
        [void]$insights.Add([PSCustomObject]@{
            Category = "INFO"
            Type     = "Flow"
            Message  = "Extended IVR navigation ($([Math]::Round($DurationAnalysis.IvrTimeSeconds / 60, 1)) minutes). Consider reviewing IVR flow complexity."
        })
    }

    # Insight: Multiple transfers
    $transferCount = 0
    foreach ($stat in $ParticipantStats) {
        if ($stat.Purpose -eq "agent" -or $stat.Purpose -eq "acd") {
            $transferCount++
        }
    }
    if ($transferCount -gt 2) {
        [void]$insights.Add([PSCustomObject]@{
            Category = "WARNING"
            Type     = "Flow"
            Message  = "Multiple transfers occurred ($transferCount agent/queue handoffs). Customer experience may be affected."
        })
    }

    # Insight: Error conditions
    $hasErrors = $false
    $errorTypes = [System.Collections.ArrayList]::new()
    foreach ($stat in $ParticipantStats) {
        if ($stat.HasErrors) {
            $hasErrors = $true
            foreach ($err in $stat.ErrorCodes) {
                if ($errorTypes -notcontains $err) {
                    [void]$errorTypes.Add($err)
                }
            }
        }
    }
    if ($hasErrors) {
        [void]$insights.Add([PSCustomObject]@{
            Category = "WARNING"
            Type     = "Error"
            Message  = "Technical errors occurred during the conversation: $($errorTypes -join ', ')"
        })
    }

    # Insight: Abnormal disconnect
    $abnormalDisconnects = @("error", "system", "timeout")
    foreach ($stat in $ParticipantStats) {
        if ($null -ne $stat.DisconnectType -and $stat.DisconnectType -ne "" -and $abnormalDisconnects -contains $stat.DisconnectType.ToLower()) {
            [void]$insights.Add([PSCustomObject]@{
                Category = "WARNING"
                Type     = "Disconnect"
                Message  = "$($stat.Name) disconnected abnormally ($($stat.DisconnectType)). May indicate technical issue."
            })
        }
    }

    # Insight: Conference call
    if ($DurationAnalysis.ConferenceSeconds -gt 0) {
        [void]$insights.Add([PSCustomObject]@{
            Category = "INFO"
            Type     = "Flow"
            Message  = "Conference call included ($([Math]::Round($DurationAnalysis.ConferenceSeconds / 60, 1)) minutes with multiple parties)."
        })
    }

    # Insight: Long total duration
    if ($DurationAnalysis.TotalDurationSeconds -gt 3600) {
        [void]$insights.Add([PSCustomObject]@{
            Category = "INFO"
            Type     = "Duration"
            Message  = "Extended conversation duration ($([Math]::Round($DurationAnalysis.TotalDurationSeconds / 60, 0)) minutes). May require follow-up review."
        })
    }

    # Insight: Short conversation (might be abandoned)
    if ($DurationAnalysis.TotalDurationSeconds -gt 0 -and $DurationAnalysis.TotalDurationSeconds -lt 30) {
        [void]$insights.Add([PSCustomObject]@{
            Category = "INFO"
            Type     = "Duration"
            Message  = "Very short conversation ($([Math]::Round($DurationAnalysis.TotalDurationSeconds, 0)) seconds). May indicate abandoned call or quick resolution."
        })
    }

    # Add a general quality rating
    $qualityRating = "Unknown"
    $ratingScore = 0

    # Score calculation based on various factors
    if ($minMos) {
        if ($minMos -ge 4.0) { $ratingScore += 3 }
        elseif ($minMos -ge 3.5) { $ratingScore += 2 }
        elseif ($minMos -ge 3.0) { $ratingScore += 1 }
    }
    if ($DurationAnalysis.HoldTimeSeconds -lt 60) { $ratingScore += 1 }
    if ($transferCount -le 1) { $ratingScore += 1 }
    if (-not $hasErrors) { $ratingScore += 2 }

    if ($ratingScore -ge 6) { $qualityRating = "Excellent" }
    elseif ($ratingScore -ge 4) { $qualityRating = "Good" }
    elseif ($ratingScore -ge 2) { $qualityRating = "Fair" }
    else { $qualityRating = "Needs Review" }

    [void]$insights.Insert(0, [PSCustomObject]@{
        Category = "OVERALL"
        Type     = "Rating"
        Message  = "Overall Quality: $qualityRating (Score: $ratingScore/8)"
    })

    return $insights
}

<#
.SYNOPSIS
    Provides human-readable explanations for common error codes.
.DESCRIPTION
    Maps Genesys Cloud error codes to user-friendly descriptions
    and potential resolution steps.
#>
function Get-GCErrorExplanation {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ErrorCode
    )

    $explanations = @{
        "error.ininedgecontrol.session.inactive"         = "Session became inactive, possibly due to network issues or timeout."
        "error.ininedgecontrol.connection.media.endpoint.idle" = "Media endpoint went idle, often due to prolonged silence or network dropout."
        "sip:400" = "Bad Request - The SIP request was malformed or invalid."
        "sip:403" = "Forbidden - The request was understood but refused."
        "sip:404" = "Not Found - The requested resource could not be found."
        "sip:408" = "Request Timeout - The server timed out waiting for the request."
        "sip:410" = "Gone - The resource is no longer available (often indicates transfer completion)."
        "sip:480" = "Temporarily Unavailable - The callee is currently unavailable."
        "sip:486" = "Busy Here - The callee is busy."
        "sip:487" = "Request Terminated - The request was terminated by a BYE or CANCEL."
        "sip:500" = "Server Internal Error - An internal server error occurred."
        "sip:502" = "Bad Gateway - The gateway received an invalid response."
        "sip:503" = "Service Unavailable - The service is temporarily unavailable."
        "sip:504" = "Gateway Timeout - The gateway timed out."
        "network.packetloss" = "Network packet loss detected, causing audio quality degradation."
        "network.jitter" = "Network jitter detected, causing inconsistent audio delivery."
    }

    if ($explanations.ContainsKey($ErrorCode)) {
        return $explanations[$ErrorCode]
    }

    # Try partial match for error codes
    foreach ($key in $explanations.Keys) {
        if ($ErrorCode -like "*$key*") {
            return $explanations[$key]
        }
    }

    return "Unknown error condition. Review system logs for details."
}

<#
.SYNOPSIS
    Formats the key insights section for the report.
.DESCRIPTION
    Creates a formatted text block with categorized insights
    that appears at the top of the report for quick review.
#>
function Format-GCKeyInsightsText {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Insights
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("*" * 60)
    [void]$sb.AppendLine("KEY INSIGHTS")
    [void]$sb.AppendLine("*" * 60)
    [void]$sb.AppendLine("")

    foreach ($insight in $Insights) {
        $icon = switch ($insight.Category) {
            "CRITICAL" { "[!!!]" }
            "WARNING"  { "[!]  " }
            "INFO"     { "[i]  " }
            "OK"       { "[OK] " }
            "OVERALL"  { "[*]  " }
            default    { "     " }
        }
        [void]$sb.AppendLine("$icon $($insight.Message)")
    }

    [void]$sb.AppendLine("")

    return $sb.ToString()
}

<#
.SYNOPSIS
    Formats the duration analysis section for the report.
.DESCRIPTION
    Creates a formatted text block showing timing breakdown
    with easy-to-read duration values.
#>
function Format-GCDurationAnalysisText {
    param (
        [Parameter(Mandatory = $true)]
        $Analysis
    )

    $sb = [System.Text.StringBuilder]::new()

    # Helper function to format seconds as human-readable duration
    function Format-Duration {
        param ([double]$Seconds)
        if ($Seconds -lt 60) {
            return "$([Math]::Round($Seconds, 0))s"
        }
        elseif ($Seconds -lt 3600) {
            $mins = [Math]::Floor($Seconds / 60)
            $secs = [Math]::Round($Seconds % 60, 0)
            return "${mins}m ${secs}s"
        }
        else {
            $hours = [Math]::Floor($Seconds / 3600)
            $mins = [Math]::Floor(($Seconds % 3600) / 60)
            return "${hours}h ${mins}m"
        }
    }

    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("DURATION ANALYSIS")
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("")

    if ($Analysis.ConversationStart -and $Analysis.ConversationEnd) {
        [void]$sb.AppendLine("Start: $($Analysis.ConversationStart.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC")
        [void]$sb.AppendLine("End:   $($Analysis.ConversationEnd.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC")
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("Timing Breakdown:")
    [void]$sb.AppendLine("  Total Duration:   $(Format-Duration $Analysis.TotalDurationSeconds)")

    if ($Analysis.IvrTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  IVR Time:         $(Format-Duration $Analysis.IvrTimeSeconds)")
    }
    if ($Analysis.QueueWaitSeconds -gt 0) {
        [void]$sb.AppendLine("  Queue Wait:       $(Format-Duration $Analysis.QueueWaitSeconds)")
    }
    if ($Analysis.AlertTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  Alert/Ring Time:  $(Format-Duration $Analysis.AlertTimeSeconds)")
    }
    if ($Analysis.InteractTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  Interaction Time: $(Format-Duration $Analysis.InteractTimeSeconds)")
    }
    if ($Analysis.AgentTalkSeconds -gt 0) {
        [void]$sb.AppendLine("  Agent Talk Time:  $(Format-Duration $Analysis.AgentTalkSeconds)")
    }
    if ($Analysis.HoldTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  Hold Time:        $(Format-Duration $Analysis.HoldTimeSeconds)")
    }
    if ($Analysis.ConferenceSeconds -gt 0) {
        [void]$sb.AppendLine("  Conference Time:  $(Format-Duration $Analysis.ConferenceSeconds)")
    }
    if ($Analysis.WrapUpSeconds -gt 0) {
        [void]$sb.AppendLine("  Wrap-up Time:     $(Format-Duration $Analysis.WrapUpSeconds)")
    }
    if ($Analysis.SystemTimeSeconds -gt 0) {
        [void]$sb.AppendLine("  System Time:      $(Format-Duration $Analysis.SystemTimeSeconds)")
    }

    # Segment type breakdown if available
    if ($Analysis.SegmentBreakdown.Count -gt 0) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("Segment Type Distribution:")
        foreach ($segType in $Analysis.SegmentBreakdown.Keys | Sort-Object) {
            $duration = $Analysis.SegmentBreakdown[$segType]
            $pct = if ($Analysis.TotalDurationSeconds -gt 0) { [Math]::Round(($duration / $Analysis.TotalDurationSeconds) * 100, 1) } else { 0 }
            [void]$sb.AppendLine("  $($segType.PadRight(15)): $(Format-Duration $duration) ($pct%)")
        }
    }

    [void]$sb.AppendLine("")

    return $sb.ToString()
}

<#
.SYNOPSIS
    Formats the participant statistics section for the report.
.DESCRIPTION
    Creates a formatted text block with per-participant details
    including timing, quality metrics, and flow information.
#>
function Format-GCParticipantStatisticsText {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Stats
    )

    $sb = [System.Text.StringBuilder]::new()

    # Helper function to format seconds as human-readable duration
    function Format-Duration {
        param ([double]$Seconds)
        if ($Seconds -lt 60) {
            return "$([Math]::Round($Seconds, 0))s"
        }
        elseif ($Seconds -lt 3600) {
            $mins = [Math]::Floor($Seconds / 60)
            $secs = [Math]::Round($Seconds % 60, 0)
            return "${mins}m ${secs}s"
        }
        else {
            $hours = [Math]::Floor($Seconds / 3600)
            $mins = [Math]::Floor(($Seconds % 3600) / 60)
            return "${hours}h ${mins}m"
        }
    }

    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("PARTICIPANT STATISTICS")
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("")

    foreach ($stat in $Stats) {
        $roleIcon = switch ($stat.Purpose) {
            "customer" { "[C]" }
            "external" { "[E]" }
            "agent"    { "[A]" }
            "acd"      { "[Q]" }
            "ivr"      { "[I]" }
            "voicemail" { "[V]" }
            default    { "[?]" }
        }

        [void]$sb.AppendLine("$roleIcon $($stat.Name)")
        [void]$sb.AppendLine("    Role: $($stat.Purpose)")
        [void]$sb.AppendLine("    Duration: $(Format-Duration $stat.TotalDurationSeconds)")
        [void]$sb.AppendLine("    Sessions: $($stat.SessionCount) | Segments: $($stat.SegmentCount)")

        if ($stat.MediaTypes.Count -gt 0) {
            [void]$sb.AppendLine("    Media: $($stat.MediaTypes -join ', ')")
        }

        # Display ANI/DNIS for customer/external participants
        if ($stat.ANI -or $stat.DNIS) {
            $contactInfo = @()
            if ($stat.ANI) { $contactInfo += "ANI: $($stat.ANI)" }
            if ($stat.DNIS) { $contactInfo += "DNIS: $($stat.DNIS)" }
            [void]$sb.AppendLine("    Contact: $($contactInfo -join ' | ')")
        }

        # Display remote party name if available
        if ($stat.RemoteName) {
            [void]$sb.AppendLine("    Remote: $($stat.RemoteName)")
        }

        if ($stat.FlowNames.Count -gt 0) {
            [void]$sb.AppendLine("    Flows: $($stat.FlowNames -join ', ')")
        }

        # Display provider info
        if ($stat.Providers.Count -gt 0) {
            [void]$sb.AppendLine("    Provider: $($stat.Providers -join ', ')")
        }

        if ($stat.MosScores.Count -gt 0) {
            $avgMos = ($stat.MosScores | Measure-Object -Average).Average
            $minMos = ($stat.MosScores | Measure-Object -Minimum).Minimum
            [void]$sb.AppendLine("    MOS: avg=$([Math]::Round($avgMos, 2)) min=$([Math]::Round($minMos, 2))")
        }

        # Display recording indicator
        if ($stat.HasRecording) {
            [void]$sb.AppendLine("    Recording: Yes")
        }

        if ($stat.DisconnectType) {
            [void]$sb.AppendLine("    Disconnect: $($stat.DisconnectType)")
        }

        if ($stat.HasErrors) {
            [void]$sb.AppendLine("    Errors: $($stat.ErrorCodes -join ', ')")
        }

        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("Legend: [C]=Customer [E]=External [A]=Agent [Q]=Queue/ACD [I]=IVR [V]=Voicemail")
    [void]$sb.AppendLine("")

    return $sb.ToString()
}

<#
.SYNOPSIS
    Formats the conversation flow path for the report.
.DESCRIPTION
    Creates a visual ASCII representation of the call flow
    showing the path through IVR, queues, and agents.
#>
function Format-GCConversationFlowText {
    param (
        [Parameter(Mandatory = $true)]
        [array]$FlowPath
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("CONVERSATION FLOW PATH")
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("")

    if ($FlowPath.Count -eq 0) {
        [void]$sb.AppendLine("No flow path data available.")
        [void]$sb.AppendLine("")
        return $sb.ToString()
    }

    $lastPurpose = ""
    foreach ($step in $FlowPath) {
        $roleIcon = switch ($step.Purpose) {
            "customer" { "[CUSTOMER]" }
            "external" { "[EXTERNAL]" }
            "agent"    { "[AGENT]   " }
            "acd"      { "[QUEUE]   " }
            "ivr"      { "[IVR]     " }
            "voicemail" { "[VM]      " }
            default    { "[OTHER]   " }
        }

        $connector = if ($lastPurpose) { "     |" } else { "" }
        if ($connector) {
            [void]$sb.AppendLine($connector)
            [void]$sb.AppendLine("     v")
        }

        [void]$sb.AppendLine("$($step.Order). $roleIcon $($step.Name)")

        if ($step.FlowName) {
            [void]$sb.AppendLine("              Flow: $($step.FlowName)")
        }

        if ($step.TransferTo) {
            [void]$sb.AppendLine("              -> Transfer to: $($step.TransferTo) ($($step.TransferType))")
        }

        $lastPurpose = $step.Purpose
    }

    [void]$sb.AppendLine("")

    return $sb.ToString()
}

function Format-ConversationReportText {
    param (
        [Parameter(Mandatory = $true)]
        $Report
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("CONVERSATION REPORT")
    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("Conversation ID: $($Report.ConversationId)")
    [void]$sb.AppendLine("Retrieved At: $($Report.RetrievedAt)")
    [void]$sb.AppendLine("")

    if ($Report.Errors -and $Report.Errors.Count -gt 0) {
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("ERRORS")
        [void]$sb.AppendLine("-" * 40)
        foreach ($err in $Report.Errors) {
            [void]$sb.AppendLine("  - $err")
        }
        [void]$sb.AppendLine("")
    }

    # Generate insight data early so we can display key insights at the top
    $events = $null
    $sortedEvents = $null
    $durationAnalysis = $null
    $participantStats = $null
    $summary = $null
    $keyInsights = $null
    $flowPath = $null
    $analysisError = $null

    try {
        # Extract events from both API responses
        $events = Get-GCConversationDetailsTimeline -Report $Report

        if ($events -and $events.Count -gt 0) {
            # Merge and sort events chronologically
            $sortedEvents = Merge-GCConversationEvents -Events $events

            # Generate analysis data
            $durationAnalysis = Get-GCConversationDurationAnalysis -Report $Report -Events $sortedEvents
            $participantStats = Get-GCParticipantStatistics -Report $Report
            $summary = Get-GCConversationSummary -ConversationId $Report.ConversationId -Events $sortedEvents
            $flowPath = Get-GCConversationFlowPath -Report $Report

            # Generate key insights (requires all other analyses)
            $keyInsights = Get-GCConversationKeyInsights -Report $Report -DurationAnalysis $durationAnalysis -ParticipantStats $participantStats -Summary $summary
        }
    }
    catch {
        # Store error but continue with report using available data
        $analysisError = $_.Exception.Message
    }

    # Display analysis error if one occurred
    if ($analysisError) {
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("ANALYSIS NOTE")
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("Some analysis sections may be incomplete due to: $analysisError")
        [void]$sb.AppendLine("")
    }

    # Display Key Insights at the top (most valuable information first)
    if ($keyInsights -and $keyInsights.Count -gt 0) {
        $insightsText = Format-GCKeyInsightsText -Insights $keyInsights
        [void]$sb.Append($insightsText)
    }

    # Display Duration Analysis
    if ($durationAnalysis) {
        $durationText = Format-GCDurationAnalysisText -Analysis $durationAnalysis
        [void]$sb.Append($durationText)
    }

    # Display Conversation Flow Path
    if ($flowPath -and $flowPath.Count -gt 0) {
        $flowText = Format-GCConversationFlowText -FlowPath $flowPath
        [void]$sb.Append($flowText)
    }

    # Display Participant Statistics
    if ($participantStats -and $participantStats.Count -gt 0) {
        $participantText = Format-GCParticipantStatisticsText -Stats $participantStats
        [void]$sb.Append($participantText)
    }

    # Conversation Details Section
    if ($Report.ConversationDetails) {
        $conv = $Report.ConversationDetails
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("CONVERSATION DETAILS")
        [void]$sb.AppendLine("-" * 40)

        if ($conv.startTime) {
            [void]$sb.AppendLine("Start Time: $($conv.startTime)")
        }
        if ($conv.endTime) {
            [void]$sb.AppendLine("End Time: $($conv.endTime)")
        }
        if ($conv.conversationStart) {
            [void]$sb.AppendLine("Conversation Start: $($conv.conversationStart)")
        }
        if ($conv.conversationEnd) {
            [void]$sb.AppendLine("Conversation End: $($conv.conversationEnd)")
        }
        if ($conv.state) {
            [void]$sb.AppendLine("State: $($conv.state)")
        }
        if ($conv.externalTag) {
            [void]$sb.AppendLine("External Tag: $($conv.externalTag)")
        }
        if ($conv.utilizationLabelId) {
            [void]$sb.AppendLine("Utilization Label ID: $($conv.utilizationLabelId)")
        }

        # Participants
        if ($conv.participants -and $conv.participants.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("Participants ($($conv.participants.Count)):")
            foreach ($participant in $conv.participants) {
                [void]$sb.AppendLine("  - Purpose: $($participant.purpose)")
                if ($participant.userId) {
                    [void]$sb.AppendLine("    User ID: $($participant.userId)")
                }
                if ($participant.name) {
                    [void]$sb.AppendLine("    Name: $($participant.name)")
                }
                if ($participant.queueId) {
                    [void]$sb.AppendLine("    Queue ID: $($participant.queueId)")
                }
                if ($participant.address) {
                    [void]$sb.AppendLine("    Address: $($participant.address)")
                }
                if ($participant.startTime) {
                    [void]$sb.AppendLine("    Start Time: $($participant.startTime)")
                }
                if ($participant.endTime) {
                    [void]$sb.AppendLine("    End Time: $($participant.endTime)")
                }
                if ($participant.wrapupRequired -ne $null) {
                    [void]$sb.AppendLine("    Wrapup Required: $($participant.wrapupRequired)")
                }
            }
        }
        [void]$sb.AppendLine("")
    }
    else {
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("CONVERSATION DETAILS: Not available")
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("")
    }

    # Analytics Details Section
    if ($Report.AnalyticsDetails) {
        $analytics = $Report.AnalyticsDetails
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("ANALYTICS DETAILS")
        [void]$sb.AppendLine("-" * 40)

        if ($analytics.conversationStart) {
            [void]$sb.AppendLine("Conversation Start: $($analytics.conversationStart)")
        }
        if ($analytics.conversationEnd) {
            [void]$sb.AppendLine("Conversation End: $($analytics.conversationEnd)")
        }
        if ($analytics.originatingDirection) {
            [void]$sb.AppendLine("Originating Direction: $($analytics.originatingDirection)")
        }
        if ($analytics.divisionIds -and $analytics.divisionIds.Count -gt 0) {
            [void]$sb.AppendLine("Division IDs: $($analytics.divisionIds -join ', ')")
        }
        if ($analytics.mediaStatsMinConversationMos) {
            [void]$sb.AppendLine("Min MOS: $($analytics.mediaStatsMinConversationMos)")
        }
        if ($analytics.mediaStatsMinConversationRFactor) {
            [void]$sb.AppendLine("Min R-Factor: $($analytics.mediaStatsMinConversationRFactor)")
        }

        # Participant Sessions
        if ($analytics.participants -and $analytics.participants.Count -gt 0) {
            [void]$sb.AppendLine("")
            [void]$sb.AppendLine("Analytics Participants ($($analytics.participants.Count)):")
            foreach ($participant in $analytics.participants) {
                [void]$sb.AppendLine("  - Participant ID: $($participant.participantId)")
                if ($participant.participantName) {
                    [void]$sb.AppendLine("    Name: $($participant.participantName)")
                }
                if ($participant.purpose) {
                    [void]$sb.AppendLine("    Purpose: $($participant.purpose)")
                }
                if ($participant.sessions -and $participant.sessions.Count -gt 0) {
                    [void]$sb.AppendLine("    Sessions: $($participant.sessions.Count)")
                    foreach ($session in $participant.sessions) {
                        if ($session.mediaType) {
                            [void]$sb.AppendLine("      Media Type: $($session.mediaType)")
                        }
                        if ($session.direction) {
                            [void]$sb.AppendLine("      Direction: $($session.direction)")
                        }
                        if ($session.ani) {
                            [void]$sb.AppendLine("      ANI: $($session.ani)")
                        }
                        if ($session.dnis) {
                            [void]$sb.AppendLine("      DNIS: $($session.dnis)")
                        }
                    }
                }
            }
        }
        [void]$sb.AppendLine("")
    }
    else {
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("ANALYTICS DETAILS: Not available")
        [void]$sb.AppendLine("-" * 40)
        [void]$sb.AppendLine("")
    }

    # Generate chronological timeline by extracting events from both endpoints
    # and interlacing them in time order
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("CHRONOLOGICAL TIMELINE")
    [void]$sb.AppendLine("-" * 40)
    [void]$sb.AppendLine("")

    # Use previously computed events if available
    if ($sortedEvents -and $sortedEvents.Count -gt 0) {
        # Format timeline text
        $timelineText = Format-GCConversationTimelineText -Events $sortedEvents
        [void]$sb.AppendLine($timelineText)

        # Generate and append summary (use pre-computed if available)
        if ($summary) {
            $summaryText = Format-GCConversationSummaryText -Summary $summary
            [void]$sb.AppendLine($summaryText)
        }
    }
    else {
        [void]$sb.AppendLine("No timeline events could be extracted from the available data.")
        [void]$sb.AppendLine("")
    }

    [void]$sb.AppendLine("=" * 60)
    [void]$sb.AppendLine("END OF REPORT")
    [void]$sb.AppendLine("=" * 60)

    return $sb.ToString()
}

$ApiBaseUrl = "https://api.usw2.pure.cloud"
$JobTracker = [PSCustomObject]@{
    Timer      = $null
    JobId      = $null
    Path       = $null
    Headers    = @{}
    Status     = ""
    ResultFile = ""
    LastUpdate = ""
}
$script:LastResponseFile = ""

function Stop-JobPolling {
    if ($JobTracker.Timer) {
        $JobTracker.Timer.Stop()
        $JobTracker.Timer = $null
    }
}

function Update-JobPanel {
    param (
        [string]$JobId,
        [string]$Status,
        [string]$Updated
    )

    if ($jobIdText) {
        $jobIdText.Text = if ($JobTracker.JobId) { $JobTracker.JobId } else { "No active job" }
    }

    if ($jobStatusText) {
        $jobStatusText.Text = if ($Status) { "Status: $Status" } else { "Status: (none)" }
    }

    if ($jobUpdatedText) {
        $jobUpdatedText.Text = if ($Updated) { "Last checked: $Updated" } else { "Last checked: --" }
    }

    if ($jobResultsPath) {
        $jobResultsPath.Text = if ($JobTracker.ResultFile) { "Results file: $($JobTracker.ResultFile)" } else { "Results file: (not available yet)" }
    }

    if ($fetchJobResultsButton) {
        $fetchJobResultsButton.IsEnabled = [bool]$JobTracker.JobId
    }

    if ($exportJobResultsButton) {
        $exportJobResultsButton.IsEnabled = (($JobTracker.ResultFile) -and (Test-Path $JobTracker.ResultFile))
    }
}

function Start-JobPolling {
    param (
        [string]$Path,
        [string]$JobId,
        [hashtable]$Headers
    )

    if (-not $Path -or -not $JobId) {
        return
    }

    Stop-JobPolling
    $JobTracker.Path = $Path.TrimEnd('/')
    $JobTracker.JobId = $JobId
    $JobTracker.Headers = $Headers
    $JobTracker.Status = "Pending"
    $JobTracker.ResultFile = ""
    Update-JobPanel -Status $JobTracker.Status -Updated (Get-Date).ToString("HH:mm:ss")

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [System.TimeSpan]::FromSeconds(6)
    $timer.Add_Tick({
        Poll-JobStatus
    })
    $JobTracker.Timer = $timer
    $timer.Start()
    Poll-JobStatus
}

function Poll-JobStatus {
    if (-not $JobTracker.JobId -or -not $JobTracker.Path) {
        return
    }

    $statusUrl = "$ApiBaseUrl$($JobTracker.Path)/$($JobTracker.JobId)"
    try {
        $statusResponse = Invoke-WebRequest -Uri $statusUrl -Method Get -Headers $JobTracker.Headers -ErrorAction Stop
        $statusJson = $statusResponse.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
        $statusValue = if ($statusJson.status) { $statusJson.status } elseif ($statusJson.state) { $statusJson.state } else { $null }
        $JobTracker.Status = $statusValue
        $JobTracker.LastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Update-JobPanel -Status $statusValue -Updated $JobTracker.LastUpdate
        Add-LogEntry "Job $($JobTracker.JobId) status checked: $statusValue"

        if (-not (Job-StatusIsPending -Status $statusValue)) {
            Stop-JobPolling
            Fetch-JobResults
        }
    } catch {
        Add-LogEntry "Job status poll failed: $($_.Exception.Message)"
    }
}

function Fetch-JobResults {
    param ([switch]$Force)

    if (-not $JobTracker.JobId -or -not $JobTracker.Path) {
        return
    }

    $resultsUrl = "$ApiBaseUrl$($JobTracker.Path)/$($JobTracker.JobId)/results"
    $tempFile = Join-Path -Path $env:TEMP -ChildPath "GenesysJobResults_$([guid]::NewGuid()).json"
    $errorMessage = $null

    try {
        Invoke-WebRequest -Uri $resultsUrl -Method Get -Headers $JobTracker.Headers -OutFile $tempFile -ErrorAction Stop
        $JobTracker.ResultFile = $tempFile
        if ($jobResultsPath) {
            $jobResultsPath.Text = "Results file: $tempFile"
        }
        $snippet = Get-Content -Path $tempFile -TotalCount 200 | Out-String
        $script:LastResponseText = "Job results saved to temp file.`r`n$tempFile`r`n`r`n${snippet}"
        $script:LastResponseRaw = $snippet.Trim()
        $script:LastResponseFile = $tempFile
        $responseBox.Text = "Job $($JobTracker.JobId) completed; results saved to temp file."
        Add-LogEntry "Job results downloaded to $tempFile"
        Update-JobPanel -Status $JobTracker.Status -Updated (Get-Date).ToString("HH:mm:ss")
    } catch {
        $errorMessage = $_.Exception.Message
        Add-LogEntry "Fetching job results failed: $errorMessage"
        $responseBox.Text = "Failed to download job results: $errorMessage"
    }
}

function Load-FavoritesFromDisk {
    param ([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        return @()
    }

    try {
        $content = Get-Content -Path $Path -Raw
        if (-not $content) {
            return @()
        }

        return $content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning "Unable to load favorites: $($_.Exception.Message)"
        return @()
    }
}

function Save-FavoritesToDisk {
    param (
        [string]$Path,
        [Parameter(Mandatory)][System.Collections.IEnumerable]$Favorites
    )

    try {
        $Favorites | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding utf8
    } catch {
        Write-Warning "Unable to save favorites: $($_.Exception.Message)"
    }
}

function Build-FavoritesCollection {
    param ($Source)

    $list = [System.Collections.ArrayList]::new()
    if (-not $Source) {
        return $list
    }

    $isEnumerable = ($Source -is [System.Collections.IEnumerable]) -and -not ($Source -is [string])
    if ($isEnumerable) {
        foreach ($item in $Source) {
            $list.Add($item) | Out-Null
        }
    } else {
        $list.Add($Source) | Out-Null
    }

    return $list
}

function Load-TemplatesFromDisk {
    param ([string]$Path)

    if (-not (Test-Path -Path $Path)) {
        return @()
    }

    try {
        $content = Get-Content -Path $Path -Raw
        if (-not $content) {
            return @()
        }

        return $content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning "Unable to load templates: $($_.Exception.Message)"
        return @()
    }
}

function Save-TemplatesToDisk {
    param (
        [string]$Path,
        [Parameter(Mandatory)][System.Collections.IEnumerable]$Templates
    )

    try {
        $Templates | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding utf8
    } catch {
        Write-Warning "Unable to save templates: $($_.Exception.Message)"
    }
}

$script:LastResponseText = ""
$script:LastResponseRaw = ""
$paramInputs = @{}
$pendingFavoriteParameters = $null

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $ScriptRoot) {
    $ScriptRoot = Get-Location
}

$UserProfileBase = if ($env:USERPROFILE) { $env:USERPROFILE } else { $ScriptRoot }
$FavoritesFile = Join-Path -Path $UserProfileBase -ChildPath "GenesysApiExplorerFavorites.json"

$JsonPath = Join-Path -Path $ScriptRoot -ChildPath "GenesysCloudAPIEndpoints.json"
if (-not (Test-Path -Path $JsonPath)) {
    Write-Error "Required endpoint catalog not found at '$JsonPath'."
    return
}

$script:CurrentJsonPath = $JsonPath
$ApiCatalog = Load-PathsFromJson -JsonPath $JsonPath
$script:ApiPaths = $ApiCatalog.Paths
$script:Definitions = if ($ApiCatalog.Definitions) { $ApiCatalog.Definitions } else { @{} }
$script:GroupMap = Build-GroupMap -Paths $script:ApiPaths
$FavoritesData = Load-FavoritesFromDisk -Path $FavoritesFile
$Favorites = Build-FavoritesCollection -Source $FavoritesData

# Load templates at startup
$TemplatesFilePath = Join-Path -Path $UserProfileBase -ChildPath "GenesysApiExplorerTemplates.json"
$TemplatesData = Load-TemplatesFromDisk -Path $TemplatesFilePath

# If no user templates exist, load default templates
if (-not $TemplatesData -or $TemplatesData.Count -eq 0) {
    $DefaultTemplatesPath = Join-Path -Path $ScriptRoot -ChildPath "DefaultTemplates.json"
    if (Test-Path -Path $DefaultTemplatesPath) {
        try {
            $TemplatesData = Load-TemplatesFromDisk -Path $DefaultTemplatesPath
            if ($TemplatesData -and $TemplatesData.Count -gt 0) {
                # Save default templates to user's template file
                Save-TemplatesToDisk -Path $TemplatesFilePath -Templates $TemplatesData
                Write-Host "Initialized with $($TemplatesData.Count) default conversation templates."
            }
        } catch {
            Write-Warning "Could not load default templates from '$DefaultTemplatesPath': $($_.Exception.Message)"
        }
    }
}

# Load example POST bodies for conversations endpoints
$ExamplePostBodiesPath = Join-Path -Path $ScriptRoot -ChildPath "ExamplePostBodies.json"
$script:ExamplePostBodies = @{}
if (Test-Path -Path $ExamplePostBodiesPath) {
    try {
        $script:ExamplePostBodies = Get-Content -Path $ExamplePostBodiesPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Warning "Could not load example POST bodies from '$ExamplePostBodiesPath': $($_.Exception.Message)"
    }
}

function Get-ExamplePostBody {
    param (
        [string]$Path,
        [string]$Method
    )

    if (-not $script:ExamplePostBodies) { return $null }

    $methodLower = $Method.ToLower()

    # Check if this path and method has an example
    $pathData = $script:ExamplePostBodies.PSObject.Properties | Where-Object { $_.Name -eq $Path }
    if ($pathData -and $pathData.Value.$methodLower -and $pathData.Value.$methodLower.example) {
        return ($pathData.Value.$methodLower.example | ConvertTo-Json -Depth 10)
    }

    return $null
}

$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Genesys Cloud API Explorer" Height="860" Width="1000"
        MinHeight="780" MinWidth="950"
        WindowStartupLocation="CenterScreen">
  <DockPanel LastChildFill="True">
    <Menu DockPanel.Dock="Top">
      <MenuItem Header="_Settings">
        <MenuItem Name="SettingsMenuItem" Header="Endpoints Configuration"/>
        <Separator/>
        <MenuItem Name="ResetEndpointsMenuItem" Header="Reset to Default"/>
      </MenuItem>
      <MenuItem Header="_Help">
        <MenuItem Name="HelpMenuItem" Header="Show Help"/>
        <Separator/>
        <MenuItem Name="HelpDevLink" Header="Developer Portal"/>
        <MenuItem Name="HelpSupportLink" Header="Genesys Support"/>
      </MenuItem>
    </Menu>
    <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="2*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="2*"/>
    </Grid.RowDefinitions>

    <TextBlock Grid.Row="0" Text="Genesys Cloud API Explorer" FontSize="20" FontWeight="Bold" Margin="0 0 0 10"/>

    <StackPanel Grid.Row="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="0 0 0 10">
      <TextBlock Text="OAuth Token:" VerticalAlignment="Center" Margin="0 0 5 0"/>
      <TextBox Name="TokenInput" Width="450" Margin="0 0 10 0" ToolTip="Paste your Genesys Cloud OAuth token here."/>
      <Button Name="TestTokenButton" Width="90" Height="26" Content="Test Token" Margin="0 0 10 0" ToolTip="Verify token validity"/>
      <TextBlock Name="TokenStatusText" VerticalAlignment="Center" Foreground="Gray" Text="Not tested"/>
    </StackPanel>

    <Grid Grid.Row="2" Margin="0 0 0 10">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <StackPanel Grid.Column="0">
        <TextBlock Text="Group" FontWeight="Bold"/>
        <ComboBox Name="GroupCombo" MinWidth="200"/>
      </StackPanel>

      <StackPanel Grid.Column="1">
        <TextBlock Text="Endpoint Path" FontWeight="Bold"/>
        <ComboBox Name="PathCombo" MinWidth="200"/>
      </StackPanel>

      <StackPanel Grid.Column="2">
        <TextBlock Text="HTTP Method" FontWeight="Bold"/>
        <ComboBox Name="MethodCombo" MinWidth="200"/>
      </StackPanel>
    </Grid>

    <Border Grid.Row="3" BorderBrush="LightGray" BorderThickness="1" Padding="10" Margin="0 0 0 10">
      <StackPanel>
        <TextBlock Text="Parameters" FontWeight="Bold" Margin="0 0 0 10"/>
        <ScrollViewer Height="220" VerticalScrollBarVisibility="Auto">
          <StackPanel Name="ParameterPanel"/>
        </ScrollViewer>
      </StackPanel>
    </Border>

    <Border Grid.Row="4" BorderBrush="LightGray" BorderThickness="1" Padding="10" Margin="0 0 0 10">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="2*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0">
          <TextBlock Text="Favorites" FontWeight="Bold" Margin="0 0 0 6"/>
          <ListBox Name="FavoritesList" DisplayMemberPath="Name" Height="120"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Margin="10 0 0 0">
          <TextBlock Text="Favorite name" FontWeight="Bold" Margin="0 0 0 6"/>
          <TextBox Name="FavoriteNameInput" Width="220" Margin="0 0 0 6"
                   ToolTip="Give the favorite a friendly label for reference."/>
          <Button Name="SaveFavoriteButton" Width="120" Height="32" Content="Save Favorite"/>
        </StackPanel>
      </Grid>
    </Border>

    <StackPanel Grid.Row="5" Orientation="Horizontal" VerticalAlignment="Center" Margin="0 0 0 10">
      <Button Name="SubmitButton" Width="150" Height="34" Content="Submit API Call" Margin="0 0 10 0"/>
      <Button Name="SaveButton" Width="150" Height="34" Content="Save Response" IsEnabled="False" Margin="0 0 10 0"/>
      <Button Name="ExportPowerShellButton" Width="150" Height="34" Content="Export PowerShell" Margin="0 0 10 0" ToolTip="Generate PowerShell script for this request"/>
      <Button Name="ExportCurlButton" Width="120" Height="34" Content="Export cURL" ToolTip="Generate cURL command for this request"/>
      <TextBlock Name="ProgressIndicator" VerticalAlignment="Center" Foreground="Blue" Margin="10 0 5 0" Visibility="Collapsed">⏳</TextBlock>
      <TextBlock Name="StatusText" VerticalAlignment="Center" Foreground="SlateGray" Margin="5 0 0 0"/>
    </StackPanel>

    <TabControl Grid.Row="6" VerticalAlignment="Stretch">
      <TabItem Header="Response">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 0 0 6">
            <Button Name="ToggleResponseViewButton" Width="140" Height="30" Content="Toggle Raw/Formatted" Margin="0 0 10 0" IsEnabled="False"/>
            <Button Name="InspectResponseButton" Width="140" Height="30" Content="Inspect Result"/>
          </StackPanel>
          <TextBox Grid.Row="1" Name="ResponseText" TextWrapping="Wrap" AcceptsReturn="True"
                   VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" IsReadOnly="True"
                   VerticalAlignment="Stretch" MinHeight="250"/>
        </Grid>
      </TabItem>
      <TabItem Header="Transparency Log">
        <Grid>
          <TextBox Name="LogText" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"
                   HorizontalScrollBarVisibility="Auto" IsReadOnly="True"
                   VerticalAlignment="Stretch" MinHeight="220"/>
        </Grid>
      </TabItem>
      <TabItem Header="Schema">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Text="Expected response structure" FontWeight="Bold" Margin="0 0 0 6"/>
          <ListView Grid.Row="1" Name="SchemaList"
                    VirtualizingStackPanel.IsVirtualizing="True"
                    VirtualizingStackPanel.VirtualizationMode="Recycling"
                    MinHeight="200">
            <ListView.View>
              <GridView>
                <GridViewColumn Header="Field" DisplayMemberBinding="{Binding Field}" Width="260"/>
                <GridViewColumn Header="Type" DisplayMemberBinding="{Binding Type}" Width="140"/>
                <GridViewColumn Header="Required" DisplayMemberBinding="{Binding Required}" Width="80"/>
                <GridViewColumn Header="Description" DisplayMemberBinding="{Binding Description}" Width="320"/>
              </GridView>
            </ListView.View>
          </ListView>
        </Grid>
      </TabItem>
      <TabItem Header="Job Watch">
        <StackPanel Margin="10">
          <TextBlock Text="Job manager" FontWeight="Bold" Margin="0 0 0 10"/>
          <TextBlock Name="JobIdText" Text="Job ID: (not set)" Margin="0 0 0 4"/>
          <TextBlock Name="JobStatusText" Text="Status: (none)" Margin="0 0 0 4"/>
          <TextBlock Name="JobUpdatedText" Text="Last checked: --" Margin="0 0 0 8"/>
          <StackPanel Orientation="Horizontal" Margin="0 0 0 6">
            <Button Name="FetchJobResultsButton" Width="150" Height="30" Content="Fetch Results"/>
            <Button Name="ExportJobResultsButton" Width="150" Height="30" Content="Export Results" Margin="10 0 0 0"/>
          </StackPanel>
          <TextBlock Name="JobResultsPath" Text="Results file: (not available yet)" TextWrapping="Wrap"/>
        </StackPanel>
      </TabItem>
      <TabItem Header="Request History">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <ListView Grid.Row="0" Name="RequestHistoryList" Height="200"
                    VirtualizingStackPanel.IsVirtualizing="True"
                    VirtualizingStackPanel.VirtualizationMode="Recycling">
            <ListView.View>
              <GridView>
                <GridViewColumn Header="Time" DisplayMemberBinding="{Binding Timestamp}" Width="140"/>
                <GridViewColumn Header="Method" DisplayMemberBinding="{Binding Method}" Width="70"/>
                <GridViewColumn Header="Path" DisplayMemberBinding="{Binding Path}" Width="280"/>
                <GridViewColumn Header="Status" DisplayMemberBinding="{Binding Status}" Width="70"/>
                <GridViewColumn Header="Duration" DisplayMemberBinding="{Binding Duration}" Width="90"/>
              </GridView>
            </ListView.View>
          </ListView>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0 10 0 0">
            <Button Name="ReplayRequestButton" Width="140" Height="30" Content="Replay Request" IsEnabled="False" ToolTip="Load the selected request into the main form"/>
            <Button Name="ClearHistoryButton" Width="140" Height="30" Content="Clear History" Margin="10 0 0 0" ToolTip="Clear all request history"/>
          </StackPanel>
        </Grid>
      </TabItem>
      <TabItem Header="Templates">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Text="Request Templates - Save and reuse API request configurations" FontWeight="Bold" Margin="0 0 0 10"/>
          <ListView Grid.Row="1" Name="TemplatesList" Height="180"
                    VirtualizingStackPanel.IsVirtualizing="True"
                    VirtualizingStackPanel.VirtualizationMode="Recycling">
            <ListView.View>
              <GridView>
                <GridViewColumn Header="Name" DisplayMemberBinding="{Binding Name}" Width="200"/>
                <GridViewColumn Header="Method" DisplayMemberBinding="{Binding Method}" Width="70"/>
                <GridViewColumn Header="Path" DisplayMemberBinding="{Binding Path}" Width="300"/>
                <GridViewColumn Header="Created" DisplayMemberBinding="{Binding Created}" Width="150"/>
              </GridView>
            </ListView.View>
          </ListView>
          <Grid Grid.Row="2" Margin="0 10 0 0">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Orientation="Horizontal">
              <Button Name="SaveTemplateButton" Width="120" Height="30" Content="Save Template" ToolTip="Save current request as a template"/>
              <Button Name="LoadTemplateButton" Width="120" Height="30" Content="Load Template" Margin="10 0 0 0" IsEnabled="False" ToolTip="Load selected template into the main form"/>
              <Button Name="DeleteTemplateButton" Width="120" Height="30" Content="Delete Template" Margin="10 0 0 0" IsEnabled="False" ToolTip="Delete selected template"/>
            </StackPanel>
            <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right">
              <Button Name="ExportTemplatesButton" Width="140" Height="30" Content="Export Templates" ToolTip="Export all templates to JSON file"/>
              <Button Name="ImportTemplatesButton" Width="140" Height="30" Content="Import Templates" Margin="10 0 0 0" ToolTip="Import templates from JSON file"/>
            </StackPanel>
          </Grid>
        </Grid>
      </TabItem>
      <TabItem Header="Conversation Report">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0 0 0 10">
            <TextBlock Text="Conversation ID:" VerticalAlignment="Center" FontWeight="Bold" Margin="0 0 8 0"/>
            <TextBox Name="ConversationReportIdInput" Width="350" Height="28" VerticalContentAlignment="Center"
                     ToolTip="Enter the conversation ID to generate a report"/>
            <Button Name="RunConversationReportButton" Width="120" Height="30" Content="Run Report" Margin="10 0 0 0"/>
          </StackPanel>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0 0 0 10">
            <Button Name="InspectConversationReportButton" Width="140" Height="30" Content="Inspect Result" IsEnabled="False"/>
            <Button Name="ExportConversationReportJsonButton" Width="140" Height="30" Content="Export JSON" Margin="10 0 0 0" IsEnabled="False"/>
            <Button Name="ExportConversationReportTextButton" Width="140" Height="30" Content="Export Text" Margin="10 0 0 0" IsEnabled="False"/>
            <TextBlock Name="ConversationReportStatus" VerticalAlignment="Center" Foreground="SlateGray" Margin="10 0 0 0"/>
          </StackPanel>
          <TextBox Grid.Row="2" Name="ConversationReportText" TextWrapping="Wrap" AcceptsReturn="True"
                   VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" IsReadOnly="True"
                   FontFamily="Consolas" FontSize="11"
                   VerticalAlignment="Stretch" MinHeight="200"/>
        </Grid>
      </TabItem>
    </TabControl>
  </Grid>
</DockPanel>
</Window>
"@

$Window = [System.Windows.Markup.XamlReader]::Parse($Xaml)
if (-not $Window) {
    Write-Error "Failed to create the WPF UI."
    return
}

$groupCombo = $Window.FindName("GroupCombo")
$pathCombo = $Window.FindName("PathCombo")
$methodCombo = $Window.FindName("MethodCombo")
$parameterPanel = $Window.FindName("ParameterPanel")
$btnSubmit = $Window.FindName("SubmitButton")
$btnSave = $Window.FindName("SaveButton")
$responseBox = $Window.FindName("ResponseText")
$logBox = $Window.FindName("LogText")
$tokenBox = $Window.FindName("TokenInput")
$testTokenButton = $Window.FindName("TestTokenButton")
$tokenStatusText = $Window.FindName("TokenStatusText")
$progressIndicator = $Window.FindName("ProgressIndicator")
$statusText = $Window.FindName("StatusText")
$favoritesList = $Window.FindName("FavoritesList")
$favoriteNameInput = $Window.FindName("FavoriteNameInput")
$saveFavoriteButton = $Window.FindName("SaveFavoriteButton")
$schemaList = $Window.FindName("SchemaList")
$inspectResponseButton = $Window.FindName("InspectResponseButton")
$toggleResponseViewButton = $Window.FindName("ToggleResponseViewButton")
$jobIdText = $Window.FindName("JobIdText")
$jobStatusText = $Window.FindName("JobStatusText")
$jobUpdatedText = $Window.FindName("JobUpdatedText")
$jobResultsPath = $Window.FindName("JobResultsPath")
$fetchJobResultsButton = $Window.FindName("FetchJobResultsButton")
$exportJobResultsButton = $Window.FindName("ExportJobResultsButton")
$helpMenuItem = $Window.FindName("HelpMenuItem")
$helpDevLink = $Window.FindName("HelpDevLink")
$helpSupportLink = $Window.FindName("HelpSupportLink")
$conversationReportIdInput = $Window.FindName("ConversationReportIdInput")
$runConversationReportButton = $Window.FindName("RunConversationReportButton")
$inspectConversationReportButton = $Window.FindName("InspectConversationReportButton")
$exportConversationReportJsonButton = $Window.FindName("ExportConversationReportJsonButton")
$exportConversationReportTextButton = $Window.FindName("ExportConversationReportTextButton")
$conversationReportText = $Window.FindName("ConversationReportText")
$conversationReportStatus = $Window.FindName("ConversationReportStatus")
$settingsMenuItem = $Window.FindName("SettingsMenuItem")
$resetEndpointsMenuItem = $Window.FindName("ResetEndpointsMenuItem")
$requestHistoryList = $Window.FindName("RequestHistoryList")
$replayRequestButton = $Window.FindName("ReplayRequestButton")
$clearHistoryButton = $Window.FindName("ClearHistoryButton")
$exportPowerShellButton = $Window.FindName("ExportPowerShellButton")
$exportCurlButton = $Window.FindName("ExportCurlButton")
$templatesList = $Window.FindName("TemplatesList")
$saveTemplateButton = $Window.FindName("SaveTemplateButton")
$loadTemplateButton = $Window.FindName("LoadTemplateButton")
$deleteTemplateButton = $Window.FindName("DeleteTemplateButton")
$exportTemplatesButton = $Window.FindName("ExportTemplatesButton")
$importTemplatesButton = $Window.FindName("ImportTemplatesButton")
$script:LastConversationReport = $null
$script:LastConversationReportJson = ""
$script:RequestHistory = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$script:ResponseViewMode = "Formatted"  # Can be "Formatted" or "Raw"
$script:Templates = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$script:TemplatesFilePath = Join-Path -Path $env:USERPROFILE -ChildPath "GenesysApiExplorerTemplates.json"

function Invoke-ReloadEndpoints {
    param (
        [string]$JsonPath
    )

    try {
        if (-not (Test-Path -Path $JsonPath)) {
            [System.Windows.MessageBox]::Show("The endpoints file does not exist at: $JsonPath", "File Not Found", "OK", "Error")
            return $false
        }

        $newCatalog = Load-PathsFromJson -JsonPath $JsonPath

        if (-not $newCatalog) {
            [System.Windows.MessageBox]::Show("Failed to load endpoints from the selected file.", "Load Error", "OK", "Error")
            return $false
        }

        # Update global variables
        $script:ApiCatalog = $newCatalog
        $script:ApiPaths = $newCatalog.Paths
        $script:Definitions = if ($newCatalog.Definitions) { $newCatalog.Definitions } else { @{} }
        $script:GroupMap = Build-GroupMap -Paths $script:ApiPaths
        $script:CurrentJsonPath = $JsonPath

        # Refresh UI
        $groupCombo.Items.Clear()
        $pathCombo.Items.Clear()
        $methodCombo.Items.Clear()
        $parameterPanel.Children.Clear()
        $paramInputs.Clear()
        $responseBox.Text = ""
        $btnSave.IsEnabled = $false

        foreach ($group in ($script:GroupMap.Keys | Sort-Object)) {
            $groupCombo.Items.Add($group) | Out-Null
        }

        $statusText.Text = "Endpoints reloaded successfully from: $(Split-Path -Leaf $JsonPath)"
        Add-LogEntry "Endpoints reloaded from: $JsonPath"

        return $true
    } catch {
        [System.Windows.MessageBox]::Show("Error loading endpoints: $($_.Exception.Message)", "Load Error", "OK", "Error")
        Add-LogEntry "Error reloading endpoints: $($_.Exception.Message)"
        return $false
    }
}

function Add-LogEntry {
    param ([string]$Message)

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    if ($logBox) {
        $logBox.AppendText("[$timestamp] $Message`r`n")
        $logBox.ScrollToEnd()
    }
}

function Refresh-FavoritesList {
    if (-not $favoritesList) { return }
    $favoritesList.Items.Clear()

    foreach ($favorite in $Favorites) {
        $favoritesList.Items.Add($favorite) | Out-Null
    }

    $favoritesList.SelectedIndex = -1
}

foreach ($group in ($script:GroupMap.Keys | Sort-Object)) {
    $groupCombo.Items.Add($group)
}

$statusText.Text = "Select a group to begin."
Refresh-FavoritesList

Update-JobPanel -Status "" -Updated ""

if ($Favorites.Count -gt 0) {
    Add-LogEntry "Loaded $($Favorites.Count) favorites from $FavoritesFile."
} else {
    Add-LogEntry "No favorites saved yet; create one from your current request."
}

Show-SplashScreen

$groupCombo.Add_SelectionChanged({
    $parameterPanel.Children.Clear()
    $paramInputs.Clear()
    $pathCombo.Items.Clear()
    $methodCombo.Items.Clear()
    $responseBox.Text = ""
    $btnSave.IsEnabled = $false

    $selectedGroup = $groupCombo.SelectedItem
    if (-not $selectedGroup) {
        return
    }

    $paths = $script:GroupMap[$selectedGroup]
    if (-not $paths) { return }
    foreach ($path in ($paths | Sort-Object)) {
        $pathCombo.Items.Add($path) | Out-Null
    }

    $statusText.Text = "Group '$selectedGroup' selected. Choose a path."
})

$pathCombo.Add_SelectionChanged({
    $methodCombo.Items.Clear()
    $parameterPanel.Children.Clear()
    $paramInputs.Clear()
    $responseBox.Text = ""
    $btnSave.IsEnabled = $false

    $selectedPath = $pathCombo.SelectedItem
    if (-not $selectedPath) { return }

    $pathObject = Get-PathObject -ApiPaths $script:ApiPaths -Path $selectedPath
    if (-not $pathObject) { return }

    foreach ($method in $pathObject.PSObject.Properties | Select-Object -ExpandProperty Name) {
        $methodCombo.Items.Add($method) | Out-Null
    }

    $statusText.Text = "Path '$selectedPath' loaded. Select a method."
})

$methodCombo.Add_SelectionChanged({
    $parameterPanel.Children.Clear()
    $paramInputs.Clear()
    $responseBox.Text = ""
    $btnSave.IsEnabled = $false

    $selectedPath = $pathCombo.SelectedItem
    $selectedMethod = $methodCombo.SelectedItem
    if (-not $selectedPath -or -not $selectedMethod) {
        return
    }

    $pathObject = Get-PathObject -ApiPaths $script:ApiPaths -Path $selectedPath
    $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
    if (-not $methodObject) {
        return
    }

    $params = $methodObject.parameters
    if (-not $params) { return }

    foreach ($param in $params) {
        $row = New-Object System.Windows.Controls.Grid
        $row.Margin = New-Object System.Windows.Thickness 0,0,0,8

        $col0 = New-Object System.Windows.Controls.ColumnDefinition
        $col0.Width = New-Object System.Windows.GridLength 240
        $row.ColumnDefinitions.Add($col0)

        $col1 = New-Object System.Windows.Controls.ColumnDefinition
        $col1.Width = New-Object System.Windows.GridLength 1, ([System.Windows.GridUnitType]::Star)
        $row.ColumnDefinitions.Add($col1)

        $label = New-Object System.Windows.Controls.TextBlock
        $label.Text = "$($param.name) ($($param.in))"
        if ($param.required) {
            $label.Text += " (required)"
        }
        $label.VerticalAlignment = "Center"
        $label.ToolTip = $param.description
        $label.Margin = New-Object System.Windows.Thickness 0,0,10,0
        [System.Windows.Controls.Grid]::SetColumn($label, 0)

        # Create appropriate control based on parameter type and metadata
        $inputControl = $null

        # Check if parameter has enum values (dropdown)
        if ($param.enum -and $param.enum.Count -gt 0) {
            $comboBox = New-Object System.Windows.Controls.ComboBox
            $comboBox.MinWidth = 360
            $comboBox.HorizontalAlignment = "Stretch"
            $comboBox.Height = 28
            if ($param.required) {
                $comboBox.Background = [System.Windows.Media.Brushes]::LightYellow
            }
            $comboBox.ToolTip = $param.description

            # Add empty option for optional parameters
            if (-not $param.required) {
                $comboBox.Items.Add("") | Out-Null
            }

            # Add enum values
            foreach ($enumValue in $param.enum) {
                $comboBox.Items.Add($enumValue) | Out-Null
            }

            # Set default value if exists
            if ($param.default) {
                $comboBox.SelectedItem = $param.default
            }

            [System.Windows.Controls.Grid]::SetColumn($comboBox, 1)
            $inputControl = $comboBox
        }
        # Check if parameter is boolean type (checkbox)
        elseif ($param.type -eq "boolean") {
            $checkBoxPanel = New-Object System.Windows.Controls.StackPanel
            $checkBoxPanel.Orientation = "Horizontal"

            $checkBox = New-Object System.Windows.Controls.CheckBox
            $checkBox.VerticalAlignment = "Center"
            $checkBox.ToolTip = $param.description
            $checkBox.Margin = New-Object System.Windows.Thickness 0,0,10,0

            # Set default value if exists
            if ($param.default -ne $null) {
                if ($param.default -eq $true -or $param.default -eq "true") {
                    $checkBox.IsChecked = $true
                }
            }

            $checkBoxLabel = New-Object System.Windows.Controls.TextBlock
            $checkBoxLabel.Text = if ($param.default -ne $null) { "(default: $($param.default))" } else { "" }
            $checkBoxLabel.VerticalAlignment = "Center"
            $checkBoxLabel.Foreground = [System.Windows.Media.Brushes]::Gray
            $checkBoxLabel.FontSize = 11

            $checkBoxPanel.Children.Add($checkBox) | Out-Null
            $checkBoxPanel.Children.Add($checkBoxLabel) | Out-Null

            [System.Windows.Controls.Grid]::SetColumn($checkBoxPanel, 1)
            $inputControl = $checkBoxPanel
            # Store reference to the checkbox itself for value retrieval
            $inputControl | Add-Member -NotePropertyName "ValueControl" -NotePropertyValue $checkBox
        }
        # Default: use textbox
        else {
            $textbox = New-Object System.Windows.Controls.TextBox
            $textbox.MinWidth = 360
            $textbox.HorizontalAlignment = "Stretch"
            $textbox.TextWrapping = "Wrap"
            $textbox.AcceptsReturn = ($param.in -eq "body")
            $textbox.Height = if ($param.in -eq "body") { 80 } else { 28 }
            if ($param.required) {
                $textbox.Background = [System.Windows.Media.Brushes]::LightYellow
            }
            $textbox.ToolTip = $param.description

            # Add real-time JSON validation for body parameters
            if ($param.in -eq "body") {
                $textbox.Tag = "body"
                $textbox.Add_TextChanged({
                    param($sender, $e)
                    $text = $sender.Text.Trim()
                    if ([string]::IsNullOrWhiteSpace($text)) {
                        # Empty is OK - will be checked as required field
                        $sender.BorderBrush = $null
                        $sender.BorderThickness = New-Object System.Windows.Thickness 1
                    } elseif (Test-JsonString -JsonString $text) {
                        # Valid JSON - green border
                        $sender.BorderBrush = [System.Windows.Media.Brushes]::Green
                        $sender.BorderThickness = New-Object System.Windows.Thickness 2
                    } else {
                        # Invalid JSON - red border
                        $sender.BorderBrush = [System.Windows.Media.Brushes]::Red
                        $sender.BorderThickness = New-Object System.Windows.Thickness 2
                    }
                })
            }

            [System.Windows.Controls.Grid]::SetColumn($textbox, 1)
            $inputControl = $textbox
        }

        $row.Children.Add($label) | Out-Null
        $row.Children.Add($inputControl) | Out-Null

        $parameterPanel.Children.Add($row) | Out-Null
        $paramInputs[$param.name] = $inputControl
    }

    $statusText.Text = "Provide values for the parameters and submit."
    if ($pendingFavoriteParameters) {
        Populate-ParameterValues -ParameterSet $pendingFavoriteParameters
        $pendingFavoriteParameters = $null
    } else {
        # Try to populate body parameter with example template if available
        $exampleBody = Get-ExamplePostBody -Path $selectedPath -Method $selectedMethod
        if ($exampleBody) {
            # Find the body parameter input and populate it
            foreach ($param in $params) {
                if ($param.in -eq "body") {
                    $bodyInput = $paramInputs[$param.name]
                    if ($bodyInput) {
                        $bodyInput.Text = $exampleBody
                        $statusText.Text = "Example body template loaded. Modify as needed and submit."
                    }
                    break
                }
            }
        }
    }
    $responseSchema = Get-ResponseSchema -MethodObject $methodObject
    Update-SchemaList -Schema $responseSchema
})

if ($favoritesList) {
    $favoritesList.Add_SelectionChanged({
        $favorite = $favoritesList.SelectedItem
        if (-not $favorite) { return }

        $favoritePath = $favorite.Path
        $favoriteMethod = $favorite.Method
        $favoriteGroup = if ($favorite.Group) { $favorite.Group } else { Get-GroupForPath -Path $favoritePath }

        if ($favoriteGroup -and $GroupMap.ContainsKey($favoriteGroup)) {
            $groupCombo.SelectedItem = $favoriteGroup
        }

        if ($favoritePath) {
            $pathCombo.SelectedItem = $favoritePath
        }

        if ($favoriteMethod) {
            $pendingFavoriteParameters = $favorite.Parameters
            $methodCombo.SelectedItem = $favoriteMethod
        }

        $statusText.Text = "Favorite '$($favorite.Name)' loaded."
        Add-LogEntry "Favorite applied: $($favorite.Name)"
    })
}

if ($saveFavoriteButton) {
    $saveFavoriteButton.Add_Click({
        $favoriteName = if ($favoriteNameInput) { $favoriteNameInput.Text.Trim() } else { "" }

        if (-not $favoriteName) {
            $statusText.Text = "Enter a name before saving a favorite."
            return
        }

        $selectedPath = $pathCombo.SelectedItem
        $selectedMethod = $methodCombo.SelectedItem
        if (-not $selectedPath -or -not $selectedMethod) {
            $statusText.Text = "Pick an endpoint and method before saving."
            return
        }

        $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
        $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
        if (-not $methodObject) {
            $statusText.Text = "Unable to read the selected method metadata."
            return
        }

        $params = $methodObject.parameters
        $paramData = @()
        foreach ($param in $params) {
            $value = ""
            $input = $paramInputs[$param.name]
            if ($input) {
                $value = $input.Text
            }

            $paramData += [PSCustomObject]@{
                name  = $param.name
                in    = $param.in
                value = $value
            }
        }

        $favoriteRecord = [PSCustomObject]@{
            Name       = $favoriteName
            Path       = $selectedPath
            Method     = $selectedMethod
            Group      = Get-GroupForPath -Path $selectedPath
            Parameters = $paramData
            Timestamp  = (Get-Date).ToString("o")
        }

        $filteredFavorites = [System.Collections.ArrayList]::new()
        foreach ($fav in $Favorites) {
            if ($fav.Name -ne $favoriteRecord.Name) {
                $filteredFavorites.Add($fav) | Out-Null
            }
        }

        $filteredFavorites.Add($favoriteRecord) | Out-Null
        $Favorites = $filteredFavorites

        Save-FavoritesToDisk -Path $FavoritesFile -Favorites $Favorites
        Refresh-FavoritesList

        if ($favoriteNameInput) {
            $favoriteNameInput.Text = ""
        }

        $statusText.Text = "Favorite '$favoriteName' saved."
        Add-LogEntry "Saved favorite '$favoriteName'."
    })
}

if ($toggleResponseViewButton) {
    $toggleResponseViewButton.Add_Click({
        if ($script:ResponseViewMode -eq "Formatted") {
            # Switch to raw
            $script:ResponseViewMode = "Raw"
            if ($script:LastResponseRaw) {
                $statusCode = if ($responseBox.Text -match "Status\s+(\d+)") { $matches[1] } else { "" }
                if ($statusCode) {
                    $newLine = [System.Environment]::NewLine
                    $responseBox.Text = "Status $statusCode (Raw):$newLine$($script:LastResponseRaw)"
                } else {
                    $responseBox.Text = $script:LastResponseRaw
                }
            }
            Add-LogEntry "Response view switched to Raw."
        } else {
            # Switch to formatted
            $script:ResponseViewMode = "Formatted"
            if ($script:LastResponseText) {
                $statusCode = if ($responseBox.Text -match "Status\s+(\d+)") { $matches[1] } else { "" }
                if ($statusCode) {
                    $newLine = [System.Environment]::NewLine
                    $responseBox.Text = "Status ${statusCode}:$newLine$($script:LastResponseText)"
                } else {
                    $responseBox.Text = $script:LastResponseText
                }
            }
            Add-LogEntry "Response view switched to Formatted."
        }
    })
}

if ($inspectResponseButton) {
    $inspectResponseButton.Add_Click({
        Show-DataInspector -JsonText $script:LastResponseRaw
    })
}

if ($settingsMenuItem) {
    $settingsMenuItem.Add_Click({
        $selectedFile = Show-SettingsDialog -CurrentJsonPath $script:CurrentJsonPath
        if ($selectedFile) {
            Invoke-ReloadEndpoints -JsonPath $selectedFile
        }
    })
}

if ($resetEndpointsMenuItem) {
    $resetEndpointsMenuItem.Add_Click({
        $defaultPath = Join-Path -Path $ScriptRoot -ChildPath "GenesysCloudAPIEndpoints.json"
        if (Test-Path -Path $defaultPath) {
            if (Invoke-ReloadEndpoints -JsonPath $defaultPath) {
                [System.Windows.MessageBox]::Show("Endpoints reset to default configuration.", "Reset Complete", "OK", "Information")
            }
        } else {
            [System.Windows.MessageBox]::Show("Default endpoints file not found at: $defaultPath", "File Not Found", "OK", "Error")
        }
    })
}

if ($testTokenButton) {
    $testTokenButton.Add_Click({
        $token = $tokenBox.Text.Trim()
        if (-not $token) {
            $tokenStatusText.Text = "No token provided"
            $tokenStatusText.Foreground = "Red"
            Add-LogEntry "Token test failed: No token provided."
            return
        }

        $testTokenButton.IsEnabled = $false
        $tokenStatusText.Text = "Testing..."
        $tokenStatusText.Foreground = "Gray"
        Add-LogEntry "Testing OAuth token validity..."

        try {
            # Test token with a simple API call to /api/v2/users/me
            $headers = @{
                "Authorization" = "Bearer $token"
                "Content-Type" = "application/json"
            }
            $testUrl = "https://api.usw2.pure.cloud/api/v2/users/me"

            $response = Invoke-WebRequest -Uri $testUrl -Method GET -Headers $headers -ErrorAction Stop

            if ($response.StatusCode -eq 200) {
                $tokenStatusText.Text = "✓ Valid"
                $tokenStatusText.Foreground = "Green"
                Add-LogEntry "Token test successful: Token is valid."
            } else {
                $tokenStatusText.Text = "⚠ Unknown status"
                $tokenStatusText.Foreground = "Orange"
                Add-LogEntry "Token test returned unexpected status: $($response.StatusCode)"
            }
        } catch {
            $tokenStatusText.Text = "✗ Invalid"
            $tokenStatusText.Foreground = "Red"
            $errorMsg = $_.Exception.Message
            Add-LogEntry "Token test failed: $errorMsg"
        } finally {
            $testTokenButton.IsEnabled = $true
        }
    })
}

if ($helpMenuItem) {
    $helpMenuItem.Add_Click({
        Show-HelpWindow
    })
}

if ($helpDevLink) {
    $helpDevLink.Add_Click({
        Launch-Url -Url $DeveloperDocsUrl
    })
}

if ($helpSupportLink) {
    $helpSupportLink.Add_Click({
        Launch-Url -Url $SupportDocsUrl
    })
}

if ($fetchJobResultsButton) {
    $fetchJobResultsButton.Add_Click({
        Fetch-JobResults -Force
    })
}

if ($exportJobResultsButton) {
    $exportJobResultsButton.Add_Click({
        if (-not $JobTracker.ResultFile -or -not (Test-Path -Path $JobTracker.ResultFile)) {
            $statusText.Text = "No job result file to export."
            return
        }

        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $dialog.Title = "Export Job Results"
        $dialog.FileName = [System.IO.Path]::GetFileName($JobTracker.ResultFile)
        if ($dialog.ShowDialog() -eq $true) {
            Copy-Item -Path $JobTracker.ResultFile -Destination $dialog.FileName -Force
            $statusText.Text = "Job results exported to $($dialog.FileName)"
            Add-LogEntry "Job results exported to $($dialog.FileName)"
        }
    })
}

if ($runConversationReportButton) {
    $runConversationReportButton.Add_Click({
        $convId = if ($conversationReportIdInput) { $conversationReportIdInput.Text.Trim() } else { "" }

        if (-not $convId) {
            if ($conversationReportStatus) {
                $conversationReportStatus.Text = "Please enter a conversation ID."
            }
            Add-LogEntry "Conversation report blocked: no conversation ID."
            return
        }

        $token = $tokenBox.Text.Trim()
        if (-not $token) {
            if ($conversationReportStatus) {
                $conversationReportStatus.Text = "Please provide an OAuth token."
            }
            Add-LogEntry "Conversation report blocked: no OAuth token."
            return
        }

        $headers = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $token"
        }

        if ($conversationReportStatus) {
            $conversationReportStatus.Text = "Fetching report..."
        }
        Add-LogEntry "Generating conversation report for: $convId"

        try {
            $script:LastConversationReport = Get-ConversationReport -ConversationId $convId -Headers $headers -BaseUrl $ApiBaseUrl
            $script:LastConversationReportJson = $script:LastConversationReport | ConvertTo-Json -Depth 20

            $reportText = Format-ConversationReportText -Report $script:LastConversationReport

            if ($conversationReportText) {
                $conversationReportText.Text = $reportText
            }

            if ($inspectConversationReportButton) {
                $inspectConversationReportButton.IsEnabled = $true
            }
            if ($exportConversationReportJsonButton) {
                $exportConversationReportJsonButton.IsEnabled = $true
            }
            if ($exportConversationReportTextButton) {
                $exportConversationReportTextButton.IsEnabled = $true
            }

            $errorCount = if ($script:LastConversationReport.Errors) { $script:LastConversationReport.Errors.Count } else { 0 }
            if ($errorCount -gt 0) {
                if ($conversationReportStatus) {
                    $conversationReportStatus.Text = "Report generated with $errorCount error(s)."
                }
                Add-LogEntry "Conversation report completed with $errorCount error(s)."
            }
            else {
                if ($conversationReportStatus) {
                    $conversationReportStatus.Text = "Report generated successfully."
                }
                Add-LogEntry "Conversation report generated successfully."
            }
        }
        catch {
            if ($conversationReportStatus) {
                $conversationReportStatus.Text = "Report failed: $($_.Exception.Message)"
            }
            Add-LogEntry "Conversation report failed: $($_.Exception.Message)"
        }
    })
}

if ($inspectConversationReportButton) {
    $inspectConversationReportButton.Add_Click({
        if ($script:LastConversationReportJson) {
            Show-DataInspector -JsonText $script:LastConversationReportJson
        }
        else {
            Add-LogEntry "No conversation report data to inspect."
        }
    })
}

if ($exportConversationReportJsonButton) {
    $exportConversationReportJsonButton.Add_Click({
        if (-not $script:LastConversationReportJson) {
            if ($conversationReportStatus) {
                $conversationReportStatus.Text = "No report data to export."
            }
            return
        }

        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $dialog.Title = "Export Conversation Report JSON"
        $dialog.FileName = "ConversationReport_$($script:LastConversationReport.ConversationId).json"
        if ($dialog.ShowDialog() -eq $true) {
            $script:LastConversationReportJson | Out-File -FilePath $dialog.FileName -Encoding utf8
            if ($conversationReportStatus) {
                $conversationReportStatus.Text = "JSON exported to $($dialog.FileName)"
            }
            Add-LogEntry "Conversation report JSON exported to $($dialog.FileName)"
        }
    })
}

if ($exportConversationReportTextButton) {
    $exportConversationReportTextButton.Add_Click({
        if (-not $script:LastConversationReport) {
            if ($conversationReportStatus) {
                $conversationReportStatus.Text = "No report data to export."
            }
            return
        }

        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
        $dialog.Title = "Export Conversation Report Text"
        $dialog.FileName = "ConversationReport_$($script:LastConversationReport.ConversationId).txt"
        if ($dialog.ShowDialog() -eq $true) {
            $reportText = Format-ConversationReportText -Report $script:LastConversationReport
            $reportText | Out-File -FilePath $dialog.FileName -Encoding utf8
            if ($conversationReportStatus) {
                $conversationReportStatus.Text = "Text exported to $($dialog.FileName)"
            }
            Add-LogEntry "Conversation report text exported to $($dialog.FileName)"
        }
    })
}

if ($requestHistoryList) {
    $requestHistoryList.ItemsSource = $script:RequestHistory

    $requestHistoryList.Add_SelectionChanged({
        if ($requestHistoryList.SelectedItem) {
            $replayRequestButton.IsEnabled = $true
        } else {
            $replayRequestButton.IsEnabled = $false
        }
    })
}

if ($replayRequestButton) {
    $replayRequestButton.Add_Click({
        $selectedHistory = $requestHistoryList.SelectedItem
        if (-not $selectedHistory) {
            Add-LogEntry "No request selected to replay."
            return
        }

        # Set the group, path, and method
        $groupCombo.SelectedItem = $selectedHistory.Group
        $pathCombo.SelectedItem = $selectedHistory.Path
        $methodCombo.SelectedItem = $selectedHistory.Method

        # Restore parameters
        if ($selectedHistory.Parameters) {
            # Use Dispatcher.Invoke to ensure UI is updated before setting parameters
            $Window.Dispatcher.Invoke([Action]{
                foreach ($paramName in $selectedHistory.Parameters.Keys) {
                    if ($paramInputs.ContainsKey($paramName)) {
                        Set-ParameterControlValue -Control $paramInputs[$paramName] -Value $selectedHistory.Parameters[$paramName]
                    }
                }
            }, [System.Windows.Threading.DispatcherPriority]::Background)
        }

        Add-LogEntry "Request loaded from history: $($selectedHistory.Method) $($selectedHistory.Path)"
        $statusText.Text = "Request loaded from history."
    })
}

if ($clearHistoryButton) {
    $clearHistoryButton.Add_Click({
        $result = [System.Windows.MessageBox]::Show(
            "Are you sure you want to clear all request history?",
            "Clear History",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            $script:RequestHistory.Clear()
            Add-LogEntry "Request history cleared."
            $statusText.Text = "History cleared."
        }
    })
}

# Export PowerShell Script button
if ($exportPowerShellButton) {
    $exportPowerShellButton.Add_Click({
        $selectedPath = $pathCombo.SelectedItem
        $selectedMethod = $methodCombo.SelectedItem
        $token = $tokenBox.Text

        if (-not $selectedPath -or -not $selectedMethod) {
            $statusText.Text = "Select a path and method first."
            return
        }

        # Collect current parameters
        $requestParams = @{}
        $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
        $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
        if ($methodObject -and $methodObject.parameters) {
            foreach ($param in $methodObject.parameters) {
                $input = $paramInputs[$param.name]
                if ($input) {
                    $value = Get-ParameterControlValue -Control $input
                    if (-not [string]::IsNullOrWhiteSpace($value)) {
                        $requestParams[$param.name] = $value
                    }
                }
            }
        }

        # Generate PowerShell script
        $script = Export-PowerShellScript -Method $selectedMethod -Path $selectedPath -Parameters $requestParams -Token $token

        # Show in dialog with copy/save options
        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1|All Files (*.*)|*.*"
        $dialog.Title = "Save PowerShell Script"
        $dialog.FileName = "GenesysAPI_$($selectedMethod)_Script.ps1"

        if ($dialog.ShowDialog() -eq $true) {
            $script | Out-File -FilePath $dialog.FileName -Encoding utf8
            $statusText.Text = "PowerShell script exported to $($dialog.FileName)"
            Add-LogEntry "PowerShell script exported to $($dialog.FileName)"

            # Copy to clipboard as well
            [System.Windows.Clipboard]::SetText($script)
            [System.Windows.MessageBox]::Show(
                "PowerShell script saved to $($dialog.FileName) and copied to clipboard.",
                "Script Exported",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
    })
}

# Export cURL Command button
if ($exportCurlButton) {
    $exportCurlButton.Add_Click({
        $selectedPath = $pathCombo.SelectedItem
        $selectedMethod = $methodCombo.SelectedItem
        $token = $tokenBox.Text

        if (-not $selectedPath -or -not $selectedMethod) {
            $statusText.Text = "Select a path and method first."
            return
        }

        # Collect current parameters
        $requestParams = @{}
        $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
        $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
        if ($methodObject -and $methodObject.parameters) {
            foreach ($param in $methodObject.parameters) {
                $input = $paramInputs[$param.name]
                if ($input) {
                    $value = Get-ParameterControlValue -Control $input
                    if (-not [string]::IsNullOrWhiteSpace($value)) {
                        $requestParams[$param.name] = $value
                    }
                }
            }
        }

        # Generate cURL command
        $curlCommand = Export-CurlCommand -Method $selectedMethod -Path $selectedPath -Parameters $requestParams -Token $token

        # Copy to clipboard and show confirmation
        [System.Windows.Clipboard]::SetText($curlCommand)
        [System.Windows.MessageBox]::Show(
            "cURL command copied to clipboard:`r`n`r`n$curlCommand",
            "cURL Exported",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        )
        $statusText.Text = "cURL command copied to clipboard."
        Add-LogEntry "cURL command generated and copied to clipboard"
    })
}

# Templates list selection changed
if ($templatesList) {
    $templatesList.ItemsSource = $script:Templates

    # Load templates from disk into the collection
    if ($TemplatesData) {
        foreach ($template in $TemplatesData) {
            $script:Templates.Add($template)
        }
    }

    $templatesList.Add_SelectionChanged({
        if ($templatesList.SelectedItem) {
            $loadTemplateButton.IsEnabled = $true
            $deleteTemplateButton.IsEnabled = $true
        } else {
            $loadTemplateButton.IsEnabled = $false
            $deleteTemplateButton.IsEnabled = $false
        }
    })
}

# Save Template button
if ($saveTemplateButton) {
    $saveTemplateButton.Add_Click({
        $selectedPath = $pathCombo.SelectedItem
        $selectedMethod = $methodCombo.SelectedItem

        if (-not $selectedPath -or -not $selectedMethod) {
            [System.Windows.MessageBox]::Show(
                "Please select a path and method before saving a template.",
                "Missing Information",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Warning
            )
            return
        }

        # Prompt for template name
        Add-Type -AssemblyName Microsoft.VisualBasic
        $templateName = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter a name for this template:",
            "Save Template",
            "$selectedMethod $selectedPath"
        )

        if ([string]::IsNullOrWhiteSpace($templateName)) {
            return
        }

        # Collect current parameters
        $requestParams = @{}
        $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
        $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
        if ($methodObject -and $methodObject.parameters) {
            foreach ($param in $methodObject.parameters) {
                $input = $paramInputs[$param.name]
                if ($input) {
                    $value = Get-ParameterControlValue -Control $input
                    if (-not [string]::IsNullOrWhiteSpace($value)) {
                        $requestParams[$param.name] = $value
                    }
                }
            }
        }

        # Create template object
        $template = [PSCustomObject]@{
            Name = $templateName
            Method = $selectedMethod.ToUpper()
            Path = $selectedPath
            Group = $groupCombo.SelectedItem
            Parameters = $requestParams
            Created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }

        # Add to collection and save
        $script:Templates.Add($template)
        Save-TemplatesToDisk -Path $script:TemplatesFilePath -Templates $script:Templates

        Add-LogEntry "Template saved: $templateName"
        $statusText.Text = "Template '$templateName' saved successfully."
    })
}

# Load Template button
if ($loadTemplateButton) {
    $loadTemplateButton.Add_Click({
        $selectedTemplate = $templatesList.SelectedItem
        if (-not $selectedTemplate) {
            return
        }

        # Set the group, path, and method
        $groupCombo.SelectedItem = $selectedTemplate.Group
        $pathCombo.SelectedItem = $selectedTemplate.Path
        $methodCombo.SelectedItem = $selectedTemplate.Method

        # Restore parameters using Dispatcher
        if ($selectedTemplate.Parameters) {
            $Window.Dispatcher.Invoke([Action]{
                foreach ($paramName in $selectedTemplate.Parameters.PSObject.Properties.Name) {
                    if ($paramInputs.ContainsKey($paramName)) {
                        Set-ParameterControlValue -Control $paramInputs[$paramName] -Value $selectedTemplate.Parameters.$paramName
                    }
                }
            }, [System.Windows.Threading.DispatcherPriority]::Background)
        }

        Add-LogEntry "Template loaded: $($selectedTemplate.Name)"
        $statusText.Text = "Template loaded: $($selectedTemplate.Name)"
    })
}

# Delete Template button
if ($deleteTemplateButton) {
    $deleteTemplateButton.Add_Click({
        $selectedTemplate = $templatesList.SelectedItem
        if (-not $selectedTemplate) {
            return
        }

        $result = [System.Windows.MessageBox]::Show(
            "Are you sure you want to delete the template '$($selectedTemplate.Name)'?",
            "Delete Template",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )

        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            $script:Templates.Remove($selectedTemplate)
            Save-TemplatesToDisk -Path $script:TemplatesFilePath -Templates $script:Templates
            Add-LogEntry "Template deleted: $($selectedTemplate.Name)"
            $statusText.Text = "Template deleted."
        }
    })
}

# Export Templates button
if ($exportTemplatesButton) {
    $exportTemplatesButton.Add_Click({
        if ($script:Templates.Count -eq 0) {
            [System.Windows.MessageBox]::Show(
                "No templates to export.",
                "Export Templates",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            return
        }

        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $dialog.Title = "Export Templates"
        $dialog.FileName = "GenesysAPIExplorerTemplates.json"

        if ($dialog.ShowDialog() -eq $true) {
            Save-TemplatesToDisk -Path $dialog.FileName -Templates $script:Templates
            $statusText.Text = "Templates exported to $($dialog.FileName)"
            Add-LogEntry "Templates exported to $($dialog.FileName)"
            [System.Windows.MessageBox]::Show(
                "Templates exported successfully to $($dialog.FileName)",
                "Export Complete",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
        }
    })
}

# Import Templates button
if ($importTemplatesButton) {
    $importTemplatesButton.Add_Click({
        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $dialog.Title = "Import Templates"

        if ($dialog.ShowDialog() -eq $true) {
            $importedTemplates = Load-TemplatesFromDisk -Path $dialog.FileName
            if ($importedTemplates -and $importedTemplates.Count -gt 0) {
                $importCount = 0
                foreach ($template in $importedTemplates) {
                    # Check if template already exists by name
                    $exists = $false
                    foreach ($existingTemplate in $script:Templates) {
                        if ($existingTemplate.Name -eq $template.Name) {
                            $exists = $true
                            break
                        }
                    }

                    if (-not $exists) {
                        $script:Templates.Add($template)
                        $importCount++
                    }
                }

                if ($importCount -gt 0) {
                    Save-TemplatesToDisk -Path $script:TemplatesFilePath -Templates $script:Templates
                    $statusText.Text = "Imported $importCount template(s)."
                    Add-LogEntry "Imported $importCount template(s) from $($dialog.FileName)"
                    [System.Windows.MessageBox]::Show(
                        "Successfully imported $importCount template(s). Duplicates were skipped.",
                        "Import Complete",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information
                    )
                } else {
                    [System.Windows.MessageBox]::Show(
                        "No new templates imported. All templates already exist.",
                        "Import Complete",
                        [System.Windows.MessageBoxButton]::OK,
                        [System.Windows.MessageBoxImage]::Information
                    )
                }
            } else {
                [System.Windows.MessageBox]::Show(
                    "No templates found in the selected file.",
                    "Import Failed",
                    [System.Windows.MessageBoxButton]::OK,
                    [System.Windows.MessageBoxImage]::Warning
                )
            }
        }
    })
}

$btnSubmit.Add_Click({
    $selectedPath = $pathCombo.SelectedItem
    $selectedMethod = $methodCombo.SelectedItem

    if (-not $selectedPath -or -not $selectedMethod) {
        $statusText.Text = "Select a path and method first."
        Add-LogEntry "Submit blocked: method or path missing."
        return
    }

    $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
    $methodObject = Get-MethodObject -PathObject $pathObject -MethodName $selectedMethod
    if (-not $methodObject) {
        Add-LogEntry "Submit blocked: method metadata missing."
        $statusText.Text = "Method metadata missing."
        return
    }

    $params = $methodObject.parameters

    # Validate required parameters and JSON body parameters
    $validationErrors = @()
    foreach ($param in $params) {
        $input = $paramInputs[$param.name]
        if ($input) {
            $value = Get-ParameterControlValue -Control $input
            if ($value -and $value.GetType().Name -eq "String") {
                $value = $value.Trim()
            }

            # Check required fields
            if ($param.required -and -not $value) {
                $validationErrors += "$($param.name) is required"
            }

            # Validate JSON format for body parameters
            if ($param.in -eq "body" -and $value) {
                if (-not (Test-JsonString -JsonString $value)) {
                    $validationErrors += "$($param.name) contains invalid JSON"
                }
            }
        } elseif ($param.required) {
            $validationErrors += "$($param.name) is required but control not found"
        }
    }

    if ($validationErrors.Count -gt 0) {
        $errorMessage = "Validation errors:`n" + ($validationErrors -join "`n")
        $statusText.Text = "Validation failed: " + ($validationErrors -join ", ")
        Add-LogEntry "Submit blocked: $errorMessage"
        [System.Windows.MessageBox]::Show($errorMessage, "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $queryParams = @{}
    $pathParams = @{}
    $bodyParams = @{}
    $headers = @{
        "Content-Type" = "application/json"
    }

    $token = $tokenBox.Text.Trim()
    if ($token) {
        $headers["Authorization"] = "Bearer $token"
    }
    else {
        Add-LogEntry "Warning: Authorization token is empty."
    }

    foreach ($param in $params) {
        $input = $paramInputs[$param.name]
        if (-not $input) { continue }

        $value = Get-ParameterControlValue -Control $input
        if ($value -and $value.GetType().Name -eq "String") {
            $value = $value.Trim()
        }
        if (-not $value) { continue }

        switch ($param.in) {
            "query"  { $queryParams[$param.name] = $value }
            "path"   { $pathParams[$param.name] = $value }
            "body"   { $bodyParams[$param.name] = $value }
            "header" { $headers[$param.name] = $value }
        }
    }

    $baseUrl = "https://api.usw2.pure.cloud"
    $pathWithReplacements = $selectedPath
    foreach ($key in $pathParams.Keys) {
        $escaped = [uri]::EscapeDataString($pathParams[$key])
        $pathWithReplacements = $pathWithReplacements -replace "\{$key\}", $escaped
    }

    $queryString = if ($queryParams.Count -gt 0) {
        "?" + ($queryParams.GetEnumerator() | ForEach-Object {
            [uri]::EscapeDataString($_.Key) + "=" + [uri]::EscapeDataString($_.Value)
        } -join "&")
    } else {
        ""
    }

    $fullUrl = $baseUrl + $pathWithReplacements + $queryString
    $body = if ($bodyParams.Count -gt 0) { $bodyParams | ConvertTo-Json -Depth 10 } else { $null }

    Add-LogEntry "Request $($selectedMethod.ToUpper()) $fullUrl"
    $statusText.Text = "Sending request..."
    $btnSubmit.IsEnabled = $false
    if ($progressIndicator) {
        $progressIndicator.Visibility = "Visible"
    }

    # Track request start time
    $requestStartTime = Get-Date

    # Store parameters for history
    $requestParams = @{}
    foreach ($param in $params) {
        $input = $paramInputs[$param.name]
        if ($input) {
            $value = Get-ParameterControlValue -Control $input
            if ($value -and $value.GetType().Name -eq "String") {
                $value = $value.Trim()
            }
            if ($value) {
                $requestParams[$param.name] = $value
            }
        }
    }

    try {
        $response = Invoke-WebRequest -Uri $fullUrl -Method $selectedMethod.ToUpper() -Headers $headers -Body $body -ErrorAction Stop
        $rawContent = $response.Content
        $formattedContent = $rawContent
        try {
            $json = $rawContent | ConvertFrom-Json -ErrorAction Stop
            $formattedContent = $json | ConvertTo-Json -Depth 10
        } catch {
            # Keep raw text if JSON parsing fails
        }

        $script:LastResponseText = $formattedContent
        $script:LastResponseRaw = $rawContent
        $script:LastResponseFile = ""
        $script:ResponseViewMode = "Formatted"
        $responseBox.Text = "Status $($response.StatusCode):`r`n$formattedContent"
        $btnSave.IsEnabled = $true
        $btnSubmit.IsEnabled = $true
        if ($toggleResponseViewButton) {
            $toggleResponseViewButton.IsEnabled = $true
        }
        if ($progressIndicator) {
            $progressIndicator.Visibility = "Collapsed"
        }

        # Calculate duration and update status
        $requestDuration = ((Get-Date) - $requestStartTime).TotalMilliseconds
        $statusText.Text = "Last call succeeded ($($response.StatusCode)) - {0:N0} ms" -f $requestDuration
        Add-LogEntry ("Response: {0} returned {1} chars in {2:N0} ms." -f $response.StatusCode, $formattedContent.Length, $requestDuration)

        # Add to request history
        $historyEntry = [PSCustomObject]@{
            Timestamp = $requestStartTime.ToString("yyyy-MM-dd HH:mm:ss")
            Method = $selectedMethod.ToUpper()
            Path = $selectedPath
            Group = $groupCombo.SelectedItem
            Status = $response.StatusCode
            Duration = "{0:N0} ms" -f $requestDuration
            Parameters = $requestParams
        }
        $script:RequestHistory.Insert(0, $historyEntry)
        # Keep only last 50 requests
        while ($script:RequestHistory.Count -gt 50) {
            $script:RequestHistory.RemoveAt(50)
        }

        if ($selectedMethod -eq "post" -and $selectedPath -match "/jobs/?$" -and $json) {
            $jobId = if ($json.id) { $json.id } elseif ($json.jobId) { $json.jobId } else { $null }
            if ($jobId) {
                Start-JobPolling -Path $selectedPath -JobId $jobId -Headers $headers
            }
        }
    } catch {
        $errorMessage = $_.Exception.Message
        $statusCode = ""
        $errorResponseBody = ""

        # Try to extract detailed error information from the HTTP response
        if ($_.Exception.Response) {
            $response = $_.Exception.Response
            if ($response -is [System.Net.HttpWebResponse]) {
                $statusCode = "Status $($response.StatusCode) ($([int]$response.StatusCode)) - "
                try {
                    $responseStream = $response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($responseStream)
                    $errorResponseBody = $reader.ReadToEnd()
                    $reader.Close()
                    $responseStream.Close()
                } catch {
                    # Could not read response body
                }
            }
        }

        # Build the display message
        $displayMessage = "Error:`r`n$statusCode$errorMessage"
        if ($errorResponseBody) {
            # Try to format as JSON if possible
            try {
                $errorJson = $errorResponseBody | ConvertFrom-Json -ErrorAction Stop
                $formattedError = $errorJson | ConvertTo-Json -Depth 5
                $displayMessage += "`r`n`r`nResponse Body:`r`n$formattedError"
            } catch {
                $displayMessage += "`r`n`r`nResponse Body:`r`n$errorResponseBody"
            }
        }

        $responseBox.Text = $displayMessage
        $btnSave.IsEnabled = $false
        $btnSubmit.IsEnabled = $true
        if ($toggleResponseViewButton) {
            $toggleResponseViewButton.IsEnabled = $false
        }
        if ($progressIndicator) {
            $progressIndicator.Visibility = "Collapsed"
        }
        $statusText.Text = "Request failed - see log."
        $script:LastResponseRaw = ""
        $script:LastResponseFile = ""

        # Add to request history
        $requestDuration = ((Get-Date) - $requestStartTime).TotalMilliseconds
        $statusForHistory = if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            [int]$_.Exception.Response.StatusCode
        } else {
            "Error"
        }
        $historyEntry = [PSCustomObject]@{
            Timestamp = $requestStartTime.ToString("yyyy-MM-dd HH:mm:ss")
            Method = $selectedMethod.ToUpper()
            Path = $selectedPath
            Group = $groupCombo.SelectedItem
            Status = $statusForHistory
            Duration = "{0:N0} ms" -f $requestDuration
            Parameters = $requestParams
        }
        $script:RequestHistory.Insert(0, $historyEntry)
        # Keep only last 50 requests
        while ($script:RequestHistory.Count -gt 50) {
            $script:RequestHistory.RemoveAt(50)
        }

        # Log detailed error information to the transparency log
        Add-LogEntry "Response error: $statusCode$errorMessage"
        if ($errorResponseBody) {
            # Truncate very long error responses for the log
            $logBody = if ($errorResponseBody.Length -gt $script:LogMaxMessageLength) {
                $errorResponseBody.Substring(0, $script:LogMaxMessageLength) + "... (truncated)"
            } else {
                $errorResponseBody
            }
            Add-LogEntry "Error response body: $logBody"
        }
    }
})

$btnSave.Add_Click({
    if (-not $script:LastResponseText) {
        return
    }

    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
    $dialog.Title = "Save API Response"
    $dialog.FileName = "GenesysResponse.json"

    if ($dialog.ShowDialog() -eq $true) {
        $script:LastResponseText | Out-File -FilePath $dialog.FileName -Encoding utf8
        $statusText.Text = "Saved response to $($dialog.FileName)"
        Add-LogEntry "Saved response to $($dialog.FileName)"
    }
})

Add-LogEntry "Loaded $($GroupMap.Keys.Count) groups from the API catalog."
$Window.ShowDialog() | Out-Null
