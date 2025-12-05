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

function Show-SplashScreen {
    $splashXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Genesys Cloud API Explorer" Height="280" Width="480" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        WindowStyle="None" AllowsTransparency="True" Background="White" Topmost="True">
  <Border Margin="10" Padding="14" BorderBrush="#FF2C2C2C" BorderThickness="1" CornerRadius="6" Background="#FFF8F9FB">
    <StackPanel>
      <TextBlock Text="Genesys Cloud API Explorer" FontSize="18" FontWeight="Bold"/>
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

function Load-APIPathsFromJson {
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
    param ([Parameter(Mandatory = $true)] $ApiPaths)

    $map = @{}
    foreach ($prop in $ApiPaths.PSObject.Properties) {
        $path = $prop.Name
        if ($path -match "^/api/v2/([^/]+)") {
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

function Populate-ParameterValues {
    param ([Parameter(ValueFromPipeline)] $ParameterSet)

    if (-not $ParameterSet) { return }
    foreach ($entry in $ParameterSet) {
        $name = $entry.name
        if (-not $name) { continue }

        $input = $paramInputs[$name]
        if ($input -and $null -ne $entry.value) {
            $input.Text = $entry.value
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

function Populate-InspectorTree {
    param (
        $Tree,
        $Data,
        [string]$Label = "root",
        [int]$Depth = 0
    )

    if (-not $Tree) { return }

    $node = New-Object System.Windows.Controls.TreeViewItem
    $isEnumerable = ($Data -is [System.Collections.IEnumerable]) -and -not ($Data -is [string])
    if ($Data -and $Data.PSObject.Properties.Count -gt 0) {
        $node.Header = "$($Label) (object)"
        foreach ($prop in $Data.PSObject.Properties) {
            Populate-InspectorTree -Tree $node -Data $prop.Value -Label "$($prop.Name)" -Depth ($Depth + 1)
        }
    }
    elseif ($isEnumerable) {
        $node.Header = "$($Label) (array)"
        $count = 0
        foreach ($item in $Data) {
            if ($count -ge 150) {
                $ellipsis = New-Object System.Windows.Controls.TreeViewItem
                $ellipsis.Header = "[...]"
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
        Populate-InspectorTree -Tree $treeView -Data $parsed -Label "root"
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

$ApiBaseUrl = "https://api.mypurecloud.com/api/v2"
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
        $exportJobResultsButton.IsEnabled = (Test-Path $JobTracker.ResultFile)
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

$ApiCatalog = Load-APIPathsFromJson -JsonPath $JsonPath
$ApiPaths = $ApiCatalog.Paths
$Definitions = if ($ApiCatalog.Definitions) { $ApiCatalog.Definitions } else { @{} }
$GroupMap = Build-GroupMap -ApiPaths $ApiPaths
$FavoritesData = Load-FavoritesFromDisk -Path $FavoritesFile
$Favorites = Build-FavoritesCollection -Source $FavoritesData

$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Genesys Cloud API Explorer" Height="780" Width="950"
        WindowStartupLocation="CenterScreen">
  <DockPanel LastChildFill="True">
    <Menu DockPanel.Dock="Top">
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
      <TextBox Name="TokenInput" Width="500" Margin="0 0 10 0" ToolTip="Paste your Genesys Cloud OAuth token here."/>
      <TextBlock Text="(kept in memory only)" VerticalAlignment="Center" Foreground="Gray"/>
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
      <Button Name="SaveButton" Width="150" Height="34" Content="Save Response" IsEnabled="False"/>
      <TextBlock Name="StatusText" VerticalAlignment="Center" Foreground="SlateGray" Margin="10 0 0 0"/>
    </StackPanel>

    <TabControl Grid.Row="6">
      <TabItem Header="Response">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0 0 0 6">
            <Button Name="InspectResponseButton" Width="140" Height="30" Content="Inspect Result"/>
          </StackPanel>
          <TextBox Grid.Row="1" Name="ResponseText" TextWrapping="Wrap" AcceptsReturn="True"
                   VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" IsReadOnly="True" Height="250"/>
        </Grid>
      </TabItem>
      <TabItem Header="Transparency Log">
        <TextBox Name="LogText" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"
                 HorizontalScrollBarVisibility="Auto" IsReadOnly="True" Height="250"/>
      </TabItem>
      <TabItem Header="Schema">
        <StackPanel>
          <TextBlock Text="Expected response structure" FontWeight="Bold" Margin="0 0 0 6"/>
          <ListView Name="SchemaList" Height="250"
                    VirtualizingStackPanel.IsVirtualizing="True"
                    VirtualizingStackPanel.VirtualizationMode="Recycling">
            <ListView.View>
              <GridView>
                <GridViewColumn Header="Field" DisplayMemberBinding="{Binding Field}" Width="260"/>
                <GridViewColumn Header="Type" DisplayMemberBinding="{Binding Type}" Width="140"/>
                <GridViewColumn Header="Required" DisplayMemberBinding="{Binding Required}" Width="80"/>
                <GridViewColumn Header="Description" DisplayMemberBinding="{Binding Description}" Width="320"/>
              </GridView>
            </ListView.View>
          </ListView>
        </StackPanel>
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
      <TabItem Header="Conversation Report">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0 0 0 10">
            <TextBlock Text="Conversation ID:" VerticalAlignment="Center" Margin="0 0 8 0" FontWeight="Bold"/>
            <TextBox Name="ConversationIdInput" Width="350" Height="26" VerticalContentAlignment="Center"
                     ToolTip="Enter a Genesys Cloud Conversation ID to generate a combined report."/>
            <Button Name="RunReportButton" Width="120" Height="28" Content="Run Report" Margin="10 0 0 0"/>
            <Button Name="OpenReportInspectorButton" Width="130" Height="28" Content="Open in Inspector" Margin="10 0 0 0" IsEnabled="False"/>
          </StackPanel>
          <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0 0 0 8">
            <Button Name="ExportReportJsonButton" Width="130" Height="28" Content="Export as JSON" IsEnabled="False"/>
            <Button Name="ExportReportTextButton" Width="130" Height="28" Content="Export as Text" Margin="10 0 0 0" IsEnabled="False"/>
          </StackPanel>
          <TextBox Grid.Row="2" Name="ConversationReportOutput" TextWrapping="Wrap" AcceptsReturn="True"
                   VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" IsReadOnly="True"
                   FontFamily="Consolas" FontSize="12"/>
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
$statusText = $Window.FindName("StatusText")
$favoritesList = $Window.FindName("FavoritesList")
$favoriteNameInput = $Window.FindName("FavoriteNameInput")
$saveFavoriteButton = $Window.FindName("SaveFavoriteButton")
$schemaList = $Window.FindName("SchemaList")
$inspectResponseButton = $Window.FindName("InspectResponseButton")
$jobIdText = $Window.FindName("JobIdText")
$jobStatusText = $Window.FindName("JobStatusText")
$jobUpdatedText = $Window.FindName("JobUpdatedText")
$jobResultsPath = $Window.FindName("JobResultsPath")
$fetchJobResultsButton = $Window.FindName("FetchJobResultsButton")
$exportJobResultsButton = $Window.FindName("ExportJobResultsButton")
$helpMenuItem = $Window.FindName("HelpMenuItem")
$helpDevLink = $Window.FindName("HelpDevLink")
$helpSupportLink = $Window.FindName("HelpSupportLink")

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

foreach ($group in ($GroupMap.Keys | Sort-Object)) {
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

    $paths = $GroupMap[$selectedGroup]
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

    $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
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

    $pathObject = Get-PathObject -ApiPaths $ApiPaths -Path $selectedPath
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
        [System.Windows.Controls.Grid]::SetColumn($textbox, 1)

        $row.Children.Add($label) | Out-Null
        $row.Children.Add($textbox) | Out-Null

        $parameterPanel.Children.Add($row) | Out-Null
        $paramInputs[$param.name] = $textbox
    }

    $statusText.Text = "Provide values for the parameters and submit."
    if ($pendingFavoriteParameters) {
        Populate-ParameterValues -ParameterSet $pendingFavoriteParameters
        $pendingFavoriteParameters = $null
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

if ($inspectResponseButton) {
    $inspectResponseButton.Add_Click({
        Show-DataInspector -JsonText $script:LastResponseRaw
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

        $value = $input.Text.Trim()
        if (-not $value) { continue }

        switch ($param.in) {
            "query"  { $queryParams[$param.name] = $value }
            "path"   { $pathParams[$param.name] = $value }
            "body"   { $bodyParams[$param.name] = $value }
            "header" { $headers[$param.name] = $value }
        }
    }

    $baseUrl = "https://api.mypurecloud.com/api/v2"
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
        $responseBox.Text = "Status $($response.StatusCode):`r`n$formattedContent"
        $btnSave.IsEnabled = $true
        $statusText.Text = "Last call succeeded ($($response.StatusCode))."
        Add-LogEntry "Response: $($response.StatusCode) returned ${($formattedContent.Length)} chars."
        if ($selectedMethod -eq "post" -and $selectedPath -match "/jobs/?$" -and $json) {
            $jobId = if ($json.id) { $json.id } elseif ($json.jobId) { $json.jobId } else { $null }
            if ($jobId) {
                Start-JobPolling -Path $selectedPath -JobId $jobId -Headers $headers
            }
        }
    } catch {
        $errorMessage = $_.Exception.Message
        $statusCode = ""
        if ($_.Exception.Response -is [System.Net.HttpWebResponse]) {
            $statusCode = "Status $($($_.Exception.Response.StatusCode)) - "
        }
        $responseBox.Text = "Error:`r`n$statusCode$errorMessage"
        $btnSave.IsEnabled = $false
        $statusText.Text = "Request failed - see log."
        $script:LastResponseRaw = ""
        $script:LastResponseFile = ""
        Add-LogEntry "Response error: $statusCode$errorMessage"
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
