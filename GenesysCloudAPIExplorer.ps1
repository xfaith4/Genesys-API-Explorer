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
        Title="Genesys Cloud API Explorer" Height="340" Width="540" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
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
        if ($input -and $entry.value -ne $null) {
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
    return $Status -imatch '^(pending|running|in[-]?progress|processing|created)$'
}

$ApiBaseUrl = "https://api.usw2.pure.cloud/api/v2"
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
$script:LastReportData = $null

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
        MinWidth="900" MinHeight="700"
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

    <Border Grid.Row="3" BorderBrush="LightGray" BorderThickness="1" Padding="10" Margin="0 0 0 10" VerticalAlignment="Stretch">
      <StackPanel>
        <TextBlock Text="Parameters" FontWeight="Bold" Margin="0 0 0 10"/>
        <ScrollViewer MinHeight="220" VerticalScrollBarVisibility="Auto">
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
      <Button Name="GenerateReportButton" Width="150" Height="34" Content="Generate Report" Margin="0 0 10 0"/>
      <TextBlock Name="StatusText" VerticalAlignment="Center" Foreground="SlateGray" Margin="10 0 0 0"/>
    </StackPanel>

    <TabControl Grid.Row="6" VerticalAlignment="Stretch" HorizontalAlignment="Stretch">
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
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto" IsReadOnly="True"
                 VerticalAlignment="Stretch" HorizontalAlignment="Stretch" MinHeight="180"/>
        </Grid>
      </TabItem>
      <TabItem Header="Transparency Log">
        <TextBox Name="LogText" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"
                 HorizontalScrollBarVisibility="Auto" IsReadOnly="True" VerticalAlignment="Stretch" HorizontalAlignment="Stretch" MinHeight="220"/>
      </TabItem>
      <TabItem Header="Schema">
        <StackPanel>
          <TextBlock Text="Expected response structure" FontWeight="Bold" Margin="0 0 0 6"/>
          <ListView Name="SchemaList" VerticalAlignment="Stretch" HorizontalAlignment="Stretch" MinHeight="200"
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
      <TabItem Header="Reporting">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Text="Conversation reporting" FontWeight="Bold" Margin="0 0 0 6"/>
          <TextBox Grid.Row="1" Name="ReportText" TextWrapping="Wrap" AcceptsReturn="True"
                   VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                   IsReadOnly="True" VerticalAlignment="Stretch" HorizontalAlignment="Stretch" MinHeight="220"/>
          <Button Grid.Row="2" Name="ExportReportButton" Width="160" Height="32" Content="Export Report"
                  HorizontalAlignment="Right" Margin="0 10 0 0" IsEnabled="False"/>
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
$generateReportButton = $Window.FindName("GenerateReportButton")
$reportText = $Window.FindName("ReportText")
$exportReportButton = $Window.FindName("ExportReportButton")

function Add-LogEntry {
    param ([string]$Message)

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    if ($logBox) {
        $logBox.AppendText("[$timestamp] $Message`r`n")
        $logBox.ScrollToEnd()
    }
}

function Normalize-MediaCategory {
    param ([string]$MediaType)

    if (-not $MediaType) {
        return $null
    }

    $normalized = $MediaType.ToLowerInvariant()
    switch ($normalized) {
        "callback" { return "voice" }
        "phone" { return "voice" }
        default { return $normalized }
    }
}

function Compute-PeakConcurrency {
    param ([System.Collections.ArrayList]$Events)

    if (-not $Events -or $Events.Count -eq 0) {
        return 0
    }

    $sorted = $Events | Sort-Object @{ Expression = { $_.Time } }, @{ Expression = { -($_.Delta) } }
    $count = 0
    $peak = 0
    foreach ($evt in $sorted) {
        $count += $evt.Delta
        if ($count -gt $peak) {
            $peak = $count
        }
    }

    return $peak
}

function Add-ConcurrencyEvent {
    param (
        [hashtable]$Store,
        [string]$Key,
        [datetime]$Start,
        [datetime]$End
    )

    if (-not $Store.ContainsKey($Key)) {
        $Store[$Key] = [System.Collections.ArrayList]::new()
    }

    $events = $Store[$Key]
    $events.Add([ordered]@{ Time = $Start; Delta = 1 }) | Out-Null
    $events.Add([ordered]@{ Time = $End; Delta = -1 }) | Out-Null
}

function Find-ConversationsCollection {
    param (
        $Node,
        [int]$Depth = 0
    )

    if (-not $Node -or $Depth -gt 4) {
        return $null
    }

    if ($Node.conversations -and ($Node.conversations -is [System.Collections.IEnumerable])) {
        return $Node.conversations
    }

    if ($Node.data -and $Node.data.conversations -and ($Node.data.conversations -is [System.Collections.IEnumerable])) {
        return $Node.data.conversations
    }

    if ($Node.results -and ($Node.results -is [System.Collections.IEnumerable])) {
        return $Node.results
    }

    if ($Node.entities -and ($Node.entities -is [System.Collections.IEnumerable])) {
        return $Node.entities
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in $Node) {
            $found = Find-ConversationsCollection -Node $item -Depth ($Depth + 1)
            if ($found) {
                return $found
            }
        }
    }

    if ($Node -and $Node.PSObject) {
        foreach ($prop in $Node.PSObject.Properties) {
            $found = Find-ConversationsCollection -Node $prop.Value -Depth ($Depth + 1)
            if ($found) {
                return $found
            }
        }
    }

    return $null
}

function Get-ConversationsCollection {
    param ($Json)

    $collection = Find-ConversationsCollection -Node $Json
    if ($collection -and ($collection | Where-Object { $_.conversationId })) {
        return $collection
    }

    return @()
}


function Get-MonthKey {
    param ([datetime]$DateTime)

    if (-not $DateTime) {
        return ""
    }

    return "{0}-{1:00}" -f $DateTime.Year, $DateTime.Month
}

function Generate-ConversationReport {
    param (
        $SourceJson
    )

    $conversations = Get-ConversationsCollection -Json $SourceJson
    if (-not $conversations.Count) {
        return $null
    }

    $agents = @{}
    $queues = @{}
    $flows = @{}
    $queueNames = @{}
    $divisionStats = @{}
    $errors = [System.Collections.ArrayList]::new()
    $monthlyStats = @{}
    $globalMediaDirectionCounts = @{}
    $voiceConcurrencyEvents = @{
        inbound  = [System.Collections.ArrayList]::new()
        outbound = [System.Collections.ArrayList]::new()
    }
    $interestMedia = @("voice", "messaging", "sms")

    foreach ($conversation in $conversations) {
        $conversationId = $conversation.conversationId
        if (-not $conversationId) {
            continue
        }

        $convoAgentSet = [System.Collections.Generic.HashSet[string]]::new()
        $convoQueueSet = [System.Collections.Generic.HashSet[string]]::new()
        $convoFlowSet = [System.Collections.Generic.HashSet[string]]::new()
        $conversationErrors = [System.Collections.Generic.HashSet[string]]::new()
        $mediaDirectionSet = [System.Collections.Generic.HashSet[string]]::new()

        $directionNormalized = if ($conversation.originatingDirection) { $conversation.originatingDirection.ToLowerInvariant() } else { "unknown" }

        $_participants = if ($conversation.participants) { $conversation.participants } else { @() }
        foreach ($participant in $_participants) {
            if ($participant.userId) {
                $agentKey = $participant.userId
                if (-not $convoAgentSet.Contains($agentKey)) {
                    $convoAgentSet.Add($agentKey) | Out-Null
                    if (-not $agents.ContainsKey($agentKey)) {
                        $agents[$agentKey] = [ordered]@{
                            UserId            = $agentKey
                            Name              = ($participant.participantName -or $participant.userId)
                            ConversationCount = 0
                        }
                    }
                    $agents[$agentKey].ConversationCount++
                }
            }

            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    if ($session.segments) {
                        foreach ($segment in $session.segments) {
                            if ($segment.queueId) {
                                $convoQueueSet.Add($segment.queueId) | Out-Null
                                if ($segment.queueName) {
                                    $queueNames[$segment.queueId] = $segment.queueName
                                }
                            }
                            if ($segment.errorCode) {
                                $conversationErrors.Add($segment.errorCode) | Out-Null
                            }
                        }
                    }

                    if ($session.flow) {
                        $flowKey = if ($session.flow.flowId) { $session.flow.flowId } else { $session.flow.flowName }
                        if ($flowKey -and -not $convoFlowSet.Contains($flowKey)) {
                            $convoFlowSet.Add($flowKey) | Out-Null
                            if (-not $flows.ContainsKey($flowKey)) {
                                $flows[$flowKey] = [ordered]@{
                                    FlowId    = $flowKey
                                    FlowName  = ($session.flow.flowName -or $flowKey)
                                    Count     = 0
                                }
                            }
                            $flows[$flowKey].Count++
                        }
                    }

                    if ($session.mediaType) {
                        $mediaCategory = Normalize-MediaCategory -MediaType $session.mediaType
                        if ($mediaCategory) {
                            $mediaDirectionSet.Add("$mediaCategory|$directionNormalized") | Out-Null
                        }
                    }
                }
            }
        }

        foreach ($queueId in $convoQueueSet) {
            if (-not $queues.ContainsKey($queueId)) {
                $queues[$queueId] = [ordered]@{
                    QueueId           = $queueId
                    QueueName         = ($queueNames[$queueId] -or "")
                    ConversationCount = 0
                }
            }
            $queues[$queueId].ConversationCount++
        }

        $minMos = $null
        if ($conversation.mediaStatsMinConversationMos -ne $null) {
            $minMos = [double]$conversation.mediaStatsMinConversationMos
        }

        $latencyValues = [System.Collections.ArrayList]::new()
        foreach ($participant in $_participants) {
            if ($participant.sessions) {
                foreach ($session in $participant.sessions) {
                    if ($session.mediaEndpointStats) {
                        foreach ($stat in $session.mediaEndpointStats) {
                            if ($stat.maxLatencyMs -ne $null) {
                                $latencyValues.Add([double]$stat.maxLatencyMs) | Out-Null
                            }
                        }
                    }
                }
            }
        }

        $avgLatency = $null
        if ($latencyValues.Count) {
            $avgLatency = ($latencyValues | Measure-Object -Average).Average
        }

        if ($conversation.divisionIds) {
            foreach ($divisionId in $conversation.divisionIds) {
                if (-not $divisionStats.ContainsKey($divisionId)) {
                    $divisionStats[$divisionId] = [ordered]@{
                        DivisionId        = $divisionId
                        ConversationCount = 0
                        MinMosSum         = 0.0
                        MinMosCount       = 0
                        LatencySum        = 0.0
                        LatencyCount      = 0
                    }
                }

                $divisionStats[$divisionId].ConversationCount++
                if ($minMos -ne $null) {
                    $divisionStats[$divisionId].MinMosSum += $minMos
                    $divisionStats[$divisionId].MinMosCount++
                }
                if ($avgLatency -ne $null) {
                    $divisionStats[$divisionId].LatencySum += $avgLatency
                    $divisionStats[$divisionId].LatencyCount++
                }
            }
        }

        if ($conversationErrors.Count -gt 0) {
            $errors.Add([ordered]@{
                ConversationId = $conversationId
                ErrorCodes     = $conversationErrors.ToArray()
            }) | Out-Null
        }

        $startTime = $null
        if ($conversation.conversationStart) {
            try {
                $startTime = [datetime]::Parse($conversation.conversationStart)
            } catch {
                $startTime = $null
            }
        }

        $endTime = $null
        if ($conversation.conversationEnd) {
            try {
                $endTime = [datetime]::Parse($conversation.conversationEnd)
            } catch {
                $endTime = $null
            }
        }

        if (-not $endTime -and $startTime) {
            $endTime = $startTime
        }

        if ($startTime -and $endTime -and $endTime -lt $startTime) {
            $endTime = $startTime
        }

        $monthKey = if ($startTime) { Get-MonthKey -DateTime $startTime } else { "" }
        $monthStart = if ($startTime) { Get-Date -Year $startTime.Year -Month $startTime.Month -Day 1 -Hour 0 -Minute 0 -Second 0 } else { $null }
        $monthEnd = if ($monthStart) { $monthStart.AddMonths(1).AddTicks(-1) } else { $null }

        foreach ($comboKey in $mediaDirectionSet) {
            $parts = $comboKey.Split("|")
            $mediaCategory = $parts[0]
            $directionCategory = $parts[1]

            if ($monthKey) {
                if (-not $monthlyStats.ContainsKey($monthKey)) {
                    $monthlyStats[$monthKey] = [ordered]@{
                        Month             = $monthKey
                        MediaTotals       = @{}
                        ConcurrencyEvents = @{}
                    }
                }

                $monthEntry = $monthlyStats[$monthKey]
                $monthEntry.MediaTotals[$comboKey] = if ($monthEntry.MediaTotals.ContainsKey($comboKey)) { $monthEntry.MediaTotals[$comboKey] + 1 } else { 1 }

                if ($monthStart -and $monthEnd -and $startTime) {
                    $intervalStart = if ($startTime -lt $monthStart) { $monthStart } else { $startTime }
                    $intervalEnd = if (-not $endTime) { $monthEnd } elseif ($endTime -gt $monthEnd) { $monthEnd } else { $endTime }
                    if ($intervalEnd -lt $intervalStart) {
                        $intervalEnd = $intervalStart
                    }
                    Add-ConcurrencyEvent -Store $monthEntry.ConcurrencyEvents -Key $comboKey -Start $intervalStart -End $intervalEnd
                }
            }

            if ($interestMedia -contains $mediaCategory) {
                if (-not $globalMediaDirectionCounts.ContainsKey($mediaCategory)) {
                    $globalMediaDirectionCounts[$mediaCategory] = @{}
                }

                if (-not $globalMediaDirectionCounts[$mediaCategory].ContainsKey($directionCategory)) {
                    $globalMediaDirectionCounts[$mediaCategory][$directionCategory] = 0
                }
                $globalMediaDirectionCounts[$mediaCategory][$directionCategory]++
            }

            if ($mediaCategory -eq "voice" -and $startTime -and $endTime -and ($directionCategory -eq "inbound" -or $directionCategory -eq "outbound")) {
                Add-ConcurrencyEvent -Store $voiceConcurrencyEvents -Key $directionCategory -Start $startTime -End $endTime
            }
        }
    }

    $divisionResults = @()
    foreach ($division in $divisionStats.GetEnumerator()) {
        $entry = $division.Value
        $averageMinMos = if ($entry.MinMosCount) { [math]::Round($entry.MinMosSum / $entry.MinMosCount, 3) } else { $null }
        $averageLatency = if ($entry.LatencyCount) { [math]::Round($entry.LatencySum / $entry.LatencyCount, 2) } else { $null }
        $divisionResults += [ordered]@{
            DivisionId        = $entry.DivisionId
            ConversationCount = $entry.ConversationCount
            AverageMinMos     = $averageMinMos
            AverageLatencyMs  = $averageLatency
        }
    }

    $monthlySummary = @()
    foreach ($monthKey in ($monthlyStats.Keys | Sort-Object)) {
        $entry = $monthlyStats[$monthKey]
        $comboSummaries = @()
        foreach ($comboKey in ($entry.MediaTotals.Keys | Sort-Object)) {
            $parts = $comboKey.Split("|")
            $mediaType = $parts[0]
            $directionType = $parts[1]
            $peak = Compute-PeakConcurrency -Events $entry.ConcurrencyEvents[$comboKey]
            $comboSummaries += [ordered]@{
                MediaType      = $mediaType
                Direction      = $directionType
                Conversations  = $entry.MediaTotals[$comboKey]
                PeakConcurrent = $peak
            }
        }
        $monthlySummary += [ordered]@{
            Month  = $monthKey
            Totals = $comboSummaries
        }
    }

    $mediaSummaryList = @()
    foreach ($media in ($globalMediaDirectionCounts.Keys | Sort-Object)) {
        foreach ($direction in ($globalMediaDirectionCounts[$media].Keys | Sort-Object)) {
            $mediaSummaryList += [ordered]@{
                MediaType     = $media
                Direction     = $direction
                Conversations = $globalMediaDirectionCounts[$media][$direction]
            }
        }
    }

    $voicePeakList = @()
    foreach ($direction in @("inbound", "outbound")) {
        $events = $voiceConcurrencyEvents[$direction]
        $voicePeakList += [ordered]@{
            Direction      = $direction
            PeakConcurrent = Compute-PeakConcurrency -Events $events
        }
    }

    return [ordered]@{
        TotalConversations        = $conversations.Count
        AgentStats                = $agents.Values
        QueueStats                = $queues.Values
        FlowStats                 = $flows.Values
        DivisionStats             = $divisionResults
        ErrorConversations        = $errors
        MonthlyMediaTotals        = $monthlySummary
        TotalMediaDirectionCounts = $mediaSummaryList
        VoicePeakConcurrent       = $voicePeakList
    }
}
function Format-ConversationReportText {
    param ($Report)

    if (-not $Report) { return "" }

    $lines = [System.Collections.ArrayList]::new()
    $lines.Add("Total conversations analyzed: $($Report.TotalConversations)") | Out-Null

    if ($Report.AgentStats.Count) {
        $lines.Add("") | Out-Null
        $lines.Add("Agents involved:") | Out-Null
        foreach ($agent in $Report.AgentStats | Sort-Object -Property ConversationCount -Descending) {
            $lines.Add("  $($agent.Name) ($($agent.UserId)): $($agent.ConversationCount) conversations") | Out-Null
        }
    }

    if ($Report.QueueStats.Count) {
        $lines.Add("") | Out-Null
        $lines.Add("Queues touched:") | Out-Null
        foreach ($queue in $Report.QueueStats | Sort-Object -Property ConversationCount -Descending) {
            $displayName = if ($queue.QueueName) { "$($queue.QueueName)" } else { "Queue ID $($queue.QueueId)" }
            $lines.Add("  $displayName: $($queue.ConversationCount) conversations") | Out-Null
        }
    }

    if ($Report.FlowStats.Count) {
        $lines.Add("") | Out-Null
        $lines.Add("Flows traversed:") | Out-Null
        foreach ($flow in $Report.FlowStats | Sort-Object -Property Count -Descending) {
            $flowLabel = if ($flow.FlowName) { $flow.FlowName } else { $flow.FlowId }
            $lines.Add("  $flowLabel: $($flow.Count) conversations") | Out-Null
        }
    }

    if ($Report.DivisionStats.Count) {
        $lines.Add("") | Out-Null
        $lines.Add("Division-level averages:") | Out-Null
        foreach ($division in $Report.DivisionStats | Sort-Object -Property DivisionId) {
            $mos = if ($division.AverageMinMos -ne $null) { $division.AverageMinMos } else { "N/A" }
            $lat = if ($division.AverageLatencyMs -ne $null) { "$($division.AverageLatencyMs) ms" } else { "N/A" }
            $lines.Add("  Division $($division.DivisionId): $($division.ConversationCount) conversations | Avg Min MOS: $mos | Avg Max Latency: $lat") | Out-Null
        }
    }

    if ($Report.ErrorConversations.Count) {
        $lines.Add("") | Out-Null
        $lines.Add("Conversations with error codes:") | Out-Null
        foreach ($entry in $Report.ErrorConversations) {
            $codes = ($entry.ErrorCodes -join ", ")
            $lines.Add("  $($entry.ConversationId): $codes") | Out-Null
        }
    }

    if ($Report.MonthlyMediaTotals.Count) {
        $lines.Add("") | Out-Null
        $lines.Add("Monthly conversation totals:") | Out-Null
        foreach ($monthEntry in $Report.MonthlyMediaTotals) {
            $lines.Add("  $($monthEntry.Month):") | Out-Null
            foreach ($combo in $monthEntry.Totals) {
                $lines.Add("    $($combo.MediaType) $($combo.Direction): $($combo.Conversations) conversations, peak $($combo.PeakConcurrent) concurrent") | Out-Null
            }
        }
    }

    if ($Report.TotalMediaDirectionCounts.Count) {
        $lines.Add("") | Out-Null
        $lines.Add("Total inbound/outbound counts by media type:") | Out-Null
        foreach ($media in $Report.TotalMediaDirectionCounts | Sort-Object MediaType, Direction) {
            $lines.Add("  $($media.MediaType) $($media.Direction): $($media.Conversations) conversations") | Out-Null
        }
    }

    if ($Report.VoicePeakConcurrent.Count) {
        $lines.Add("") | Out-Null
        $lines.Add("Peak concurrent voice conversations:") | Out-Null
        foreach ($entry in $Report.VoicePeakConcurrent) {
            $lines.Add("  $($entry.Direction): $($entry.PeakConcurrent)") | Out-Null
        }
    }

    return [string]::Join("`r`n", $lines)
}

function Get-ConversationIdsFromJson {
    param ($Json)

    $ids = [System.Collections.ArrayList]::new()
    $stack = New-Object System.Collections.ArrayList
    if ($Json) {
        $stack.Add($Json) | Out-Null
    }

    while ($stack.Count -gt 0) {
        $current = $stack[$stack.Count - 1]
        $stack.RemoveAt($stack.Count - 1)
        if (-not $current) {
            continue
        }

        if ($current -is [string]) {
            continue
        }

        if ($current -is [System.Collections.IDictionary]) {
            if ($current.ContainsKey("conversationId")) {
                $candidate = $current["conversationId"]
                if ($candidate -and -not $ids.Contains($candidate.ToString())) {
                    $ids.Add($candidate.ToString()) | Out-Null
                }
            }

            foreach ($value in $current.Values) {
                if ($value) {
                    $stack.Add($value) | Out-Null
                }
            }

            continue
        }

        if ($current -is [System.Collections.IEnumerable]) {
            foreach ($item in $current) {
                if ($item) {
                    $stack.Add($item) | Out-Null
                }
            }
        }
    }

    return $ids
}

function Get-ConversationAnalyticsDetails {
    param (
        [string]$BaseUrl,
        [hashtable]$Headers,
        [string]$ConversationId
    )

    if (-not $ConversationId) {
        return $null
    }

    $url = "$BaseUrl/analytics/conversations/$ConversationId/details"
    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -Headers $Headers -ErrorAction Stop
        return $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
    } catch {
        Add-LogEntry "Analytics detail fetch for $ConversationId failed: $($_.Exception.Message)"
        return $null
    }
}

function Get-ConversationResource {
    param (
        [string]$BaseUrl,
        [hashtable]$Headers,
        [string]$ConversationId
    )

    if (-not $ConversationId) {
        return $null
    }

    $url = "$BaseUrl/conversations/$ConversationId"
    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -Headers $Headers -ErrorAction Stop
        return $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
    } catch {
        Add-LogEntry "Conversation fetch for $ConversationId failed: $($_.Exception.Message)"
        return $null
    }
}

# Enrich analytics responses with correlated conversation and analytics detail objects.
function Invoke-ConversationsEnrichment {
    param (
        [string]$BaseUrl,
        [hashtable]$Headers,
        $SourceJson,
        [int]$MaxConversations = 5
    )

    if (-not $SourceJson) {
        return $null
    }

    $conversationIds = Get-ConversationIdsFromJson -Json $SourceJson
    if (-not $conversationIds.Count) {
        return $null
    }

    $records = [System.Collections.ArrayList]::new()
    $seen = [System.Collections.ArrayList]::new()
    foreach ($conversationId in $conversationIds) {
        if (-not $conversationId) {
            continue
        }

        if ($seen.Contains($conversationId)) {
            continue
        }

        $seen.Add($conversationId) | Out-Null

        $analyticsDetail = Get-ConversationAnalyticsDetails -BaseUrl $BaseUrl -Headers $Headers -ConversationId $conversationId
        $conversation = Get-ConversationResource -BaseUrl $BaseUrl -Headers $Headers -ConversationId $conversationId

        $records.Add([ordered]@{
            ConversationId                 = $conversationId
            AnalyticsConversationDetail    = $analyticsDetail
            ConversationResource           = $conversation
        }) | Out-Null

        if ($records.Count -ge $MaxConversations) {
            break
        }
    }

    if ($records.Count -eq 0) {
        return $null
    }

    return [PSCustomObject]@{
        EnrichedConversations = $records
        ConversationCount     = $records.Count
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

    $baseUrl = "https://api.usw2.pure.cloud/api/v2"
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
        $combinedText = ""
        if ($json -and $selectedPath -match "/analytics/conversations") {
            $enriched = Invoke-ConversationsEnrichment -BaseUrl $baseUrl -Headers $headers -SourceJson $json
            if ($enriched) {
                $combinedJson = $enriched | ConvertTo-Json -Depth 10
                $combinedText = "`r`n`r`nCombined conversation data:`r`n$combinedJson"
                Add-LogEntry "Conversation enrichment returned $($enriched.ConversationCount) records."
            }
        }
        $responseBox.Text = "Status $($response.StatusCode):`r`n$formattedContent$combinedText"
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

if ($generateReportButton) {
    $generateReportButton.Add_Click({
        if (-not $script:LastResponseRaw) {
            $statusText.Text = "Run an API request before generating a report."
            Add-LogEntry "Report generation skipped: no response data."
            return
        }

        try {
            $json = $script:LastResponseRaw | ConvertFrom-Json -Depth 10 -ErrorAction Stop
        } catch {
            $statusText.Text = "Unable to parse the response for reporting."
            Add-LogEntry "Report generation failed: $($_.Exception.Message)"
            return
        }

        $report = Generate-ConversationReport -SourceJson $json
        if (-not $report) {
            $statusText.Text = "No conversation data found for reporting."
            if ($reportText) {
                $reportText.Text = "No conversation data found. Try a different endpoint."
            }
            $script:LastReportData = $null
            if ($exportReportButton) {
                $exportReportButton.IsEnabled = $false
            }
            Add-LogEntry "Report generation returned no data."
            return
        }

        $script:LastReportData = $report
        if ($reportText) {
            $reportText.Text = Format-ConversationReportText -Report $report
        }
        $statusText.Text = "Report generated for $($report.TotalConversations) conversations."
        if ($exportReportButton) {
            $exportReportButton.IsEnabled = $true
        }
        Add-LogEntry "Conversation report generated for $($report.TotalConversations) entries."
    })
}

if ($exportReportButton) {
    $exportReportButton.Add_Click({
        if (-not $script:LastReportData) {
            $statusText.Text = "Generate a report before exporting."
            return
        }

        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $dialog.Title = "Export Conversation Report"
        $dialog.FileName = "ConversationReport.json"

        if ($dialog.ShowDialog() -eq $true) {
            $script:LastReportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $dialog.FileName -Encoding utf8
            $statusText.Text = "Report saved to $($dialog.FileName)"
            Add-LogEntry "Conversation report exported to $($dialog.FileName)"
        }
    })
}

Add-LogEntry "Loaded $($GroupMap.Keys.Count) groups from the API catalog."
$Window.ShowDialog() | Out-Null
