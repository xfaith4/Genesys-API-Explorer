<#
.SYNOPSIS
    Minimal WPF scaffold for Genesys Cloud API Explorer

.DESCRIPTION
    This is an initial WPF shell to evolve toward a richer desktop experience.
    It mirrors the WinForms version at a high level (token, path/method pickers,
    body editor, preview/response, history), but only scaffolds the UI — logic
    is intentionally minimal to keep this patch focused.

    Next steps:
    - Bind API path/method lists and parameter forms
    - Wire up body editors (JSON/form/multipart) and submit action
    - Share common API logic with the WinForms script
#>

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. "$PSScriptRoot/GenesysCloudAPI.Common.ps1"

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Genesys Cloud API Explorer (WPF)" Height="720" Width="1000">
  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Top controls -->
    <Grid Grid.Row="0" Margin="0,0,0,8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="300"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="300"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="150"/>
      </Grid.ColumnDefinitions>
      <TextBlock Text="OAuth Token:" VerticalAlignment="Center" Margin="0,0,6,0"/>
      <PasswordBox x:Name="TokenBox" Grid.Column="1"/>
      <TextBlock Text="Path:" Grid.Column="2" Margin="16,0,6,0" VerticalAlignment="Center"/>
      <ComboBox x:Name="PathCombo" Grid.Column="3"/>
      <TextBlock Text="Method:" Grid.Column="4" Margin="16,0,6,0" VerticalAlignment="Center"/>
      <ComboBox x:Name="MethodCombo" Grid.Column="5"/>
    </Grid>

    <!-- Middle: Tabs -->
    <TabControl Grid.Row="1">
      <TabItem Header="Parameters">
        <ScrollViewer>
          <StackPanel x:Name="ParamsHost" Margin="8"/>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="Body">
        <Grid Margin="8">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,8">
            <TextBlock Text="Body Type:" VerticalAlignment="Center" Margin="0,0,6,0"/>
            <ComboBox x:Name="BodyType" Width="260">
              <ComboBoxItem Content="None"/>
              <ComboBoxItem Content="application/json"/>
              <ComboBoxItem Content="application/x-www-form-urlencoded"/>
              <ComboBoxItem Content="multipart/form-data"/>
            </ComboBox>
            <Button Content="Format JSON" x:Name="FormatJson" Margin="12,0,0,0"/>
            <Button Content="Add Field" x:Name="AddField" Margin="12,0,0,0" Visibility="Collapsed"/>
          </StackPanel>
          <Grid Grid.Row="1">
            <TextBox x:Name="JsonEditor" FontFamily="Consolas" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" Visibility="Collapsed"/>
            <StackPanel x:Name="FormEditor" Visibility="Collapsed"/>
          </Grid>
        </Grid>
      </TabItem>

      <TabItem Header="Preview &amp; Response">
        <Grid Margin="8">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="150"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <TextBlock Text="Request Preview:"/>
          <TextBox x:Name="Preview" Grid.Row="1" FontFamily="Consolas" IsReadOnly="True" TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto"/>
          <TextBlock Text="API Response:" Grid.Row="2" Margin="0,8,0,0"/>
          <TextBox x:Name="Response" Grid.Row="3" IsReadOnly="True" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <TabItem Header="History">
        <ListBox x:Name="HistoryList" Margin="8"/>
      </TabItem>
    </TabControl>

    <!-- Bottom buttons -->
    <StackPanel Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Right" >
      <Button x:Name="Submit" Content="Submit API Call" Width="140" Margin="0,8,8,0"/>
      <Button x:Name="Save" Content="Save Response" Width="120" IsEnabled="False"/>
    </StackPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Fetch controls
$TokenBox   = $window.FindName("TokenBox")
$PathCombo  = $window.FindName("PathCombo")
$MethodCombo= $window.FindName("MethodCombo")
$ParamsHost = $window.FindName("ParamsHost")
$BodyType   = $window.FindName("BodyType")
$JsonEditor = $window.FindName("JsonEditor")
$FormEditor = $window.FindName("FormEditor")
$AddField   = $window.FindName("AddField")
$FormatJson = $window.FindName("FormatJson")
$Preview    = $window.FindName("Preview")
$Response   = $window.FindName("Response")
$HistoryList= $window.FindName("HistoryList")
$SubmitBtn  = $window.FindName("Submit")
$SaveBtn    = $window.FindName("Save")

# Load API definitions
$JsonPath = Join-Path $PSScriptRoot 'GenesysCloudAPIEndpoints.json'
$apiPaths = Load-APIPathsFromJson -JsonPath $JsonPath
$PathCombo.ItemsSource = $apiPaths.PSObject.Properties.Name | Sort-Object

# Parameter binding
$PathCombo.add_SelectionChanged({
    $MethodCombo.ItemsSource = @()
    $ParamsHost.Children.Clear()
    $selectedPath = $PathCombo.SelectedItem
    if ($selectedPath) {
        $methods = Get-MethodsForPath -pathObject ($apiPaths.$selectedPath).Value
        $MethodCombo.ItemsSource = $methods
    }
})

$MethodCombo.add_SelectionChanged({
    $ParamsHost.Children.Clear()
    $selectedPath = $PathCombo.SelectedItem
    $selectedMethod = $MethodCombo.SelectedItem
    if ($selectedPath -and $selectedMethod) {
        $methodObject = ($apiPaths.$selectedPath).Value.$selectedMethod
        $params = Get-ParametersForMethod -methodObject $methodObject
        if ($params) {
            foreach ($param in $params) {
                $grid = New-Object Windows.Controls.Grid
                $grid.Margin = '0,0,0,4'
                $grid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
                $grid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
                $label = New-Object Windows.Controls.TextBlock
                $label.Text = "$($param.name) ($($param.in))"
                $label.Margin = '0,0,8,0'
                $textbox = New-Object Windows.Controls.TextBox
                $textbox.Tag = [PSCustomObject]@{name=$param.name; in=$param.in}
                $grid.Children.Add($label)
                [Windows.Controls.Grid]::SetColumn($textbox,1)
                $grid.Children.Add($textbox)
                $ParamsHost.Children.Add($grid)
            }
        }
    }
})

function Add-FormField {
    $row = New-Object Windows.Controls.StackPanel
    $row.Orientation = "Horizontal"
    $row.Margin = "0,0,0,4"
    $keyBox = New-Object Windows.Controls.TextBox
    $keyBox.Width = 120
    $keyBox.Margin = "0,0,4,0"
    $valBox = New-Object Windows.Controls.TextBox
    $valBox.Width = 200
    $row.Children.Add($keyBox)
    $row.Children.Add($valBox)
    $FormEditor.Children.Add($row)
}
$AddField.add_Click({ Add-FormField })

function Update-BodyEditors {
    switch ($BodyType.Text) {
        "application/json" {
            $JsonEditor.Visibility = "Visible"
            $FormEditor.Visibility = "Collapsed"
            $FormatJson.IsEnabled = $true
            $AddField.Visibility = "Collapsed"
        }
        "application/x-www-form-urlencoded" {
            $JsonEditor.Visibility = "Collapsed"
            $FormEditor.Visibility = "Visible"
            $FormatJson.IsEnabled = $false
            $AddField.Visibility = "Visible"
            if ($FormEditor.Children.Count -eq 0) { Add-FormField }
        }
        "multipart/form-data" {
            $JsonEditor.Visibility = "Collapsed"
            $FormEditor.Visibility = "Visible"
            $FormatJson.IsEnabled = $false
            $AddField.Visibility = "Visible"
            if ($FormEditor.Children.Count -eq 0) { Add-FormField }
        }
        default {
            $JsonEditor.Visibility = "Collapsed"
            $FormEditor.Visibility = "Collapsed"
            $FormatJson.IsEnabled = $false
            $AddField.Visibility = "Collapsed"
        }
    }
}
$BodyType.add_SelectionChanged({ Update-BodyEditors })
Update-BodyEditors

$FormatJson.add_Click({
    try {
        $JsonEditor.Text = ($JsonEditor.Text | ConvertFrom-Json | ConvertTo-Json -Depth 10)
    } catch {}
})

$SubmitBtn.add_Click({
    $selectedPath = $PathCombo.SelectedItem
    $selectedMethod = $MethodCombo.SelectedItem
    if (-not $selectedPath -or -not $selectedMethod) { return }
    $methodObject = ($apiPaths.$selectedPath).Value.$selectedMethod
    $params = Get-ParametersForMethod -methodObject $methodObject

    $queryParams = @{}
    $pathParams = @{}
    $bodyParams = @{}
    $headers = @{
        "Authorization" = "Bearer $($TokenBox.Password)"
        "Content-Type"  = $BodyType.Text
    }

    foreach ($child in $ParamsHost.Children) {
        $textbox = $child.Children[1]
        $meta = $textbox.Tag
        if ($textbox.Text) {
            switch ($meta.in) {
                "query" { $queryParams[$meta.name] = $textbox.Text }
                "path"  { $pathParams[$meta.name] = $textbox.Text }
                "body"  { $bodyParams[$meta.name] = $textbox.Text }
                "header"{ $headers[$meta.name] = $textbox.Text }
            }
        }
    }

    $bodyType = $BodyType.Text
    if ($bodyType -eq "application/json") {
        if ($JsonEditor.Text) {
            try { $bodyParams = $JsonEditor.Text | ConvertFrom-Json } catch { $bodyParams = @{} }
        }
    } elseif ($bodyType -eq "application/x-www-form-urlencoded" -or $bodyType -eq "multipart/form-data") {
        $bodyParams = @{}
        foreach ($row in $FormEditor.Children) {
            $k = $row.Children[0].Text
            $v = $row.Children[1].Text
            if ($k) { $bodyParams[$k] = $v }
        }
    }

    $baseUrl = "https://api.mypurecloud.com/api/v2"
    try {
        $result = Invoke-GenesysApi -BaseUrl $baseUrl -Path $selectedPath -Method $selectedMethod -PathParams $pathParams -QueryParams $queryParams -BodyParams $bodyParams -Headers $headers -BodyType $bodyType
        $respJson = $result.Response | ConvertTo-Json -Depth 10
        $Preview.Text = "$selectedMethod $($result.Url)`n" + ($headers.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } -join "`n") + (if ($result.BodyString) { "`n`n$result.BodyString" } else { "" })
        $Response.Text = $respJson
        $script:LastResponseText = $respJson
        $HistoryList.Items.Add((Get-Date -Format HH:mm:ss) + " $selectedMethod $($result.Url)")
        $SaveBtn.IsEnabled = $true
    } catch {
        $Preview.Text = ""
        $Response.Text = "Error: $($_.Exception.Message)"
        $script:LastResponseText = ""
        $SaveBtn.IsEnabled = $false
    }
})

$SaveBtn.add_Click({
    if ($script:LastResponseText) {
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
        $dlg.FileName = "API_Response.json"
        if ($dlg.ShowDialog()) {
            $script:LastResponseText | Out-File -FilePath $dlg.FileName -Encoding utf8
        }
    }
})

$null = $window.ShowDialog()
