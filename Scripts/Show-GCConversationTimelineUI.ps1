### BEGIN FILE: Show-GCConversationTimelineUI.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUri,

    [Parameter(Mandatory = $true)]
    [string]$AccessToken,

    # Optional: preload and auto-load this conversation on open
    [Parameter(Mandatory = $false)]
    [string]$ConversationId
)

# Ensure the timeline function is available
if (-not (Get-Command -Name Get-GCConversationTimeline -ErrorAction SilentlyContinue)) {
    throw "Get-GCConversationTimeline is not available. Import your Genesys toolbox module before running this UI."
}

# WPF assemblies (works in Windows PowerShell; in PS 7 use Windows with full .NET Desktop)
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase

# Simple WPF layout: input row + grid + status bar
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Genesys Cloud Conversation Timeline"
        Height="600" Width="1000"
        WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,8">
      <TextBlock Text="Conversation ID:" VerticalAlignment="Center" Margin="0,0,4,0"/>
      <TextBox x:Name="ConversationIdBox" Width="300" Margin="0,0,8,0"/>
      <Button x:Name="LoadButton" Content="Load" Width="80" Margin="0,0,8,0"/>
      <TextBlock Text="Base URI:" VerticalAlignment="Center" Margin="16,0,4,0"/>
      <TextBox x:Name="BaseUriBox" Width="260" Margin="0,0,8,0"/>
    </StackPanel>

    <DataGrid x:Name="TimelineGrid"
              Grid.Row="1"
              AutoGenerateColumns="True"
              IsReadOnly="True"
              CanUserAddRows="False"
              CanUserDeleteRows="False"
              Margin="0,0,0,4" />

    <TextBlock x:Name="StatusText"
               Grid.Row="2"
               Margin="0,4,0,0"
               TextWrapping="Wrap"
               Foreground="Gray" />
  </Grid>
</Window>
"@

# Parse XAML into WPF objects
[xml]$xamlXml = $xaml
$reader      = New-Object System.Xml.XmlNodeReader $xamlXml
$window      = [Windows.Markup.XamlReader]::Load($reader)

# Grab controls we care about
$conversationIdBox = $window.FindName('ConversationIdBox')
$loadButton        = $window.FindName('LoadButton')
$baseUriBox        = $window.FindName('BaseUriBox')
$timelineGrid      = $window.FindName('TimelineGrid')
$statusText        = $window.FindName('StatusText')

# Seed the BaseUri so you don't retype it every time
$baseUriBox.Text = $BaseUri

# Seed ConversationId if we were given one
if ($ConversationId) {
    $conversationIdBox.Text = $ConversationId
}

# Core handler that loads the timeline
$loadHandler = {
    try {
        $convId = $conversationIdBox.Text.Trim()
        $base   = $baseUriBox.Text.Trim()

        if ([string]::IsNullOrWhiteSpace($convId)) {
            $statusText.Text = "Please enter a Conversation ID."
            return
        }

        if ([string]::IsNullOrWhiteSpace($base)) {
            $statusText.Text = "Please enter a Base URI."
            return
        }

        $statusText.Text = "Loading conversation $convId ..."
        $window.Cursor   = [System.Windows.Input.Cursors]::Wait

        # Call toolbox function to get the bundle
        $bundle = Get-GCConversationTimeline -BaseUri $base -AccessToken $AccessToken -ConversationId $convId -Verbose:$false

        if (-not $bundle) {
            $statusText.Text = "No data returned for conversation $convId."
            $timelineGrid.ItemsSource = $null
            return
        }

        # Bind TimelineEvents directly to the grid
        $timelineGrid.ItemsSource = $bundle.TimelineEvents

        $count = if ($bundle.TimelineEvents) { $bundle.TimelineEvents.Count } else { 0 }
        $statusText.Text = "Loaded $count events for conversation $convId."
    }
    catch {
        $statusText.Text = "Error loading conversation: $($_.Exception.Message)"
    }
    finally {
        $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    }
}

# Wire up button click
$loadButton.Add_Click($loadHandler)

# Allow hitting Enter in the ConversationId box to trigger load
$conversationIdBox.Add_KeyDown({
    param($s,$e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        & $loadHandler
    }
})

# If we got a ConversationId param, auto-load it when the window shows
if ($ConversationId) {
    $window.Add_Loaded({
        & $loadHandler
    })
}

# Show the WPF window modally
$window.ShowDialog() | Out-Null
### END FILE: Show-GCConversationTimelineUI.ps1
