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
          </StackPanel>
          <Grid Grid.Row="1">
            <TextBox x:Name="JsonEditor" FontFamily="Consolas" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"/>
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
      <Button x:Name="Save" Content="Save Response" Width="120"/>
    </StackPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# simple show
$null = $window.ShowDialog()

