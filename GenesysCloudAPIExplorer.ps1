<#
.SYNOPSIS
    Genesys Cloud API Explorer GUI Tool

.DESCRIPTION
    Loads Genesys Cloud API JSON definitions and allows interactive exploration.
    Dynamically builds and sends REST API calls with support for:
    - Query, Path, Body, and Header parameters
    - Authorization header
    - Viewing responses
    - Saving results to file

.NOTES
    Future Enhancements:
    - OAuth Token Input
    - Request preview window
	- Request logging and timestamped history
    - More body types (formData, multipart, etc.)
	- Enhanced body editor for POST/PUT JSON
	- WPF or Universal Dashboard version
#>
# Load required UI libraries
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.HttpListener

function Load-ExampleBodies {
    param ([string]$JsonPath)
    if (Test-Path $JsonPath) {
        return Get-Content $JsonPath -Raw | ConvertFrom-Json
    }
    return @{}
}

function Generate-ExampleFromSchema($schema) {
    $result = @{}
    if ($schema -and $schema.properties) {
        foreach ($prop in $schema.properties.PSObject.Properties) {
            $key = $prop.Name
            $val = $prop.Value
            $exampleVal = $val.example
            if (-not $exampleVal) {
                $exampleVal = switch ($val.type) {
                    "string" { "string" }
                    "integer" { 0 }
                    "boolean" { $false }
                    "array" { @() }
                    default { $null }
                }
            }
            $result[$key] = $exampleVal
        }
    }
    return $result
}

function Update-ExampleCurl {
    param(
        [string] $method,
        [string] $rawPath,         # e.g. "/api/v2/content/.../{workspaceId}/tagvalues"
        [array]  $paramDefs,       # the $params array from Get-ParametersForMethod
        [object] $panelParams,     # your Panel holding the TextBoxes
        [object] $txtExample       # the TextBox to update
    )

    # 1) Gather path & query values (use user text or a placeholder)
    $pathParams = @{}
    $queryParams = @{}
    foreach ($p in $paramDefs) {
        $tb = $panelParams.Controls | Where-Object { $_.Name -eq "param_$($p.name)" }
        $val = if ($tb.Text) { $tb.Text } else {
            # placeholder or default
            switch ($p.type) {
                "string" { "<$($p.name)>" }
                "integer" { 0 }
                "boolean" { $false }
                "array" { "[]" }
                default { "<$($p.name)>" }
            }
        }

        if ($p.in -eq "path") { $pathParams[$p.name] = $val }
        if ($p.in -eq "query") { $queryParams[$p.name] = $val }
    }

    # replace path parameters
    $urlPath = $rawPath
    foreach ($k in $pathParams.Keys) {
        $urlPath = $urlPath -replace "\{$k\}", [uri]::EscapeDataString($pathParams[$k])
    }

    # build query string
    $qs = ""
    if ($queryParams.Count) {
        $pairs = $queryParams.GetEnumerator() | ForEach-Object {
            [uri]::EscapeDataString($_.Key) + "=" + [uri]::EscapeDataString($_.Value)
        }
        $qs = "?" + ($pairs -join "&")
    }

    # 2) Body example (if any)
    $bodyParam = $paramDefs | Where-Object { $_.in -eq "body" }
    if ($bodyParam -and $bodyParam.schema) {
        $exampleBody = Generate-ExampleFromSchema $bodyParam.schema
        $jsonBody = $exampleBody | ConvertTo-Json -Depth 10
        $dataFlag = " -d '$jsonBody'"
    }
    else {
        $dataFlag = ""
    }

    # 3) Assemble curl
    $fullUrl = "https://api.mypurecloud.com" + $urlPath + $qs
    $curl = @()
    $curl += "curl -X $($method.ToUpper()) `"" + $fullUrl + "`""
    $curl += "    -H `"Authorization: Bearer <YOUR_TOKEN>`""
    if ($dataFlag) { $curl += "    -H `"Content-Type: application/json`"$dataFlag" }
    $txtExample.Text = $curl -join "`n"
}

function Start-OAuthListener {
    param (
        [string]$RedirectUri = "http://localhost:8080/callback",
        [string]$OrgName
    )

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:8080/callback/")
    $listener.Start()

    Write-Host "Listening for redirect..."
    $context = $listener.GetContext()
    $response = $context.Response

    $tokenFragment = $context.Request.RawUrl.Split("#")[1]
    $params = @{ }
    $tokenFragment -split '&' | ForEach-Object {
        $kv = $_ -split '='
        $params[$kv[0]] = [uri]::UnescapeDataString($kv[1])
    }

    $token = $params['access_token']

    # Send response to browser
    $html = "<html><body><h2>You may now close this window.</h2></body></html>"
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.OutputStream.Close()
    $listener.Stop()

    # Save to text and JSON file in ./auth
    if (-not (Test-Path "auth")) { New-Item -ItemType Directory -Path "auth" | Out-Null }
    $tokenPath = "auth/OAuthToken.txt"
    $jsonPath = "auth/OAuthToken.json"
    $timestamp = Get-Date -Format o
    Set-Content -Path $tokenPath -Value "Bearer $token"
    $tokenObj = [PSCustomObject]@{
        token     = $token
        org       = $OrgName
        timestamp = $timestamp
    }
    $tokenObj | ConvertTo-Json | Set-Content -Path $jsonPath

    return $token
}
function Load-APIPathsFromJson {
    param ([string]$JsonPath)
    $json = Get-Content $JsonPath -Raw | ConvertFrom-Json
    return $json.'openapi-cache-https---api-mypurecloud-com-api-v2-docs-swagger'.paths
}

function Get-MethodsForPath {
    param ($pathObject)
    return $pathObject.PSObject.Properties.Name
}

function Get-ParametersForMethod {
    param ($methodObject)
    return $methodObject.parameters
}

function Build-GUI {
    param ($apiPaths)

    # → 0) Ensure WinForms assemblies are loaded
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # → 1) Main form
    $formParams = @{
        Text          = "Genesys Cloud API Explorer"
        Size          = New-Object System.Drawing.Size(800, 700)
        StartPosition = "CenterScreen"
    }
    $form = New-Object System.Windows.Forms.Form -Property $formParams

    # → 2) Top: TableLayoutPanel for Category / Path / Method
    $tlpParams = @{
        RowCount    = 3
        ColumnCount = 2
        Size        = New-Object System.Drawing.Size(760, 100)
        Location    = New-Object System.Drawing.Point(20, 10)
        AutoSize    = $false
    }
    $tlp = New-Object System.Windows.Forms.TableLayoutPanel -Property $tlpParams
    # column: label auto / combo stretch
    $tlp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("AutoSize")))
    $tlp.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle("Percent", 100)))
    # rows: all autosize
    1..3 | ForEach-Object { $tlp.RowStyles.Add((New-Object System.Windows.Forms.RowStyle("AutoSize"))) }
    $form.Controls.Add($tlp)

    # --- Category row ---
    $lblCatParams = @{
        Text     = "Category:"
        AutoSize = $true
    }
    $lblGroups = New-Object System.Windows.Forms.Label -Property $lblCatParams
    $tlp.Controls.Add($lblGroups, 0, 0)

    $cbCatParams = @{
        DropDownStyle = "DropDownList"
        Width         = 600
    }
    $comboGroups = New-Object System.Windows.Forms.ComboBox -Property $cbCatParams
    $tlp.Controls.Add($comboGroups, 1, 0)

    # --- Path row ---
    $lblPathParams = @{
        Text     = "Path:"
        AutoSize = $true
    }
    $lblPaths = New-Object System.Windows.Forms.Label -Property $lblPathParams
    $tlp.Controls.Add($lblPaths, 0, 1)

    $cbPathParams = @{
        DropDownStyle = "DropDownList"
        Width         = 600
    }
    $comboPaths = New-Object System.Windows.Forms.ComboBox -Property $cbPathParams
    $tlp.Controls.Add($comboPaths, 1, 1)

    # --- Method row ---
    $lblMethodParams = @{
        Text     = "Method:"
        AutoSize = $true
    }
    $lblMethods = New-Object System.Windows.Forms.Label -Property $lblMethodParams
    $tlp.Controls.Add($lblMethods, 0, 2)

    $cbMethParams = @{
        DropDownStyle = "DropDownList"
        Width         = 600
    }
    $comboMethods = New-Object System.Windows.Forms.ComboBox -Property $cbMethParams
    $tlp.Controls.Add($comboMethods, 1, 2)

    # → 3) Middle: TabControl
    $tabCtrlParams = @{
        Size     = New-Object System.Drawing.Size(760, 400)
        Location = New-Object System.Drawing.Point(20, 120)
    }
    $tabs = New-Object System.Windows.Forms.TabControl -Property $tabCtrlParams
    $form.Controls.Add($tabs)

    # --- Tab 1: Parameters ---
    $tab1Params = @{
        Text = "Parameters"
    }
    $tabParams = New-Object System.Windows.Forms.TabPage -Property $tab1Params
    $tabs.TabPages.Add($tabParams)

    $panelParamsParams = @{
        Location   = New-Object System.Drawing.Point(0, 0)
        Size       = New-Object System.Drawing.Size(750, 370)
        AutoScroll = $true
    }
    $panelParams = New-Object System.Windows.Forms.Panel -Property $panelParamsParams
    $tabParams.Controls.Add($panelParams)

    # --- Tab 2: Example & Response ---
    $tab2Params = @{
        Text = "Example & Response"
    }
    $tabExample = New-Object System.Windows.Forms.TabPage -Property $tab2Params
    $tabs.TabPages.Add($tabExample)

    # Example Request textbox
    $lblExParams = @{
        Text     = "Example Request:"
        AutoSize = $true
        Location = New-Object System.Drawing.Point(5, 5)
    }
    $lblExample = New-Object System.Windows.Forms.Label -Property $lblExParams
    $tabExample.Controls.Add($lblExample)

    $txtExParams = @{
        Multiline  = $true
        ReadOnly   = $true
        ScrollBars = "Vertical"
        Font       = New-Object System.Drawing.Font("Consolas", 9)
        Location   = New-Object System.Drawing.Point(5, 25)
        Size       = New-Object System.Drawing.Size(740, 160)
    }
    $txtExample = New-Object System.Windows.Forms.TextBox -Property $txtExParams
    $tabExample.Controls.Add($txtExample)

    # API Response textbox
    $lblRespParams = @{
        Text     = "API Response:"
        AutoSize = $true
        Location = New-Object System.Drawing.Point(5, 195)
    }
    $lblResponse = New-Object System.Windows.Forms.Label -Property $lblRespParams
    $tabExample.Controls.Add($lblResponse)

    $txtRespParams = @{
        Multiline  = $true
        ReadOnly   = $true
        ScrollBars = "Vertical"
        Location   = New-Object System.Drawing.Point(5, 215)
        Size       = New-Object System.Drawing.Size(740, 150)
    }
    $resultBox = New-Object System.Windows.Forms.TextBox -Property $txtRespParams
    $tabExample.Controls.Add($resultBox)
    # → 4) Bottom: action buttons
    $btnSubmitParams = @{
        Text     = "Submit API Call"
        Size     = New-Object System.Drawing.Size(120, 30)
        Location = New-Object System.Drawing.Point(580, 540)
    }
    $btnSubmit = New-Object System.Windows.Forms.Button -Property $btnSubmitParams
    $form.Controls.Add($btnSubmit)

    $btnSaveParams = @{
        Text     = "Save Response"
        Enabled  = $false
        Size     = New-Object System.Drawing.Size(120, 30)
        Location = New-Object System.Drawing.Point(700, 540)
    }
    $btnSave = New-Object System.Windows.Forms.Button -Property $btnSaveParams
    $form.Controls.Add($btnSave)

    $groupMap = @{}
    foreach ($prop in $apiPaths.PSObject.Properties) {
        $path = $prop.Name
        if ($path -match "^/api/v2/([^/]+)") {
            $group = $Matches[1]
            if (-not $groupMap.ContainsKey($group)) {
                $groupMap[$group] = @()
            }
            $groupMap[$group] += $path
        }
    }
    $comboGroups.Items.AddRange(($groupMap.Keys | Sort-Object))

    $comboGroups.Add_SelectedIndexChanged({
            $selectedGroup = $comboGroups.SelectedItem
            $comboPaths.Items.Clear()

            if ($groupMap.ContainsKey($selectedGroup)) {
                $comboPaths.Items.AddRange(($groupMap[$selectedGroup] | Sort-Object))
            }

            $comboPaths.SelectedIndex = -1
            $comboMethods.Items.Clear()
            $panelParams.Controls.Clear()

            # clear example & response when you change category
            $txtExample.Clear()
            $resultBox.Clear()
        })

    $comboPaths.Add_SelectedIndexChanged({
            $comboMethods.Items.Clear()
            $panelParams.Controls.Clear()

            $selectedPath = $comboPaths.SelectedItem
            $selectedPathObject = $apiPaths.$selectedPath

            if ($null -ne $selectedPathObject) {
                $methods = Get-MethodsForPath -pathObject $selectedPathObject
                $comboMethods.Items.AddRange($methods)
            }
            # clear example & response when you change path
            $txtExample.Clear()
            $resultBox.Clear()
        })

    $comboMethods.Add_SelectedIndexChanged({
            # clear out old params
            $panelParams.Controls.Clear()

            # grab selections
            $selectedPath = $comboPaths.SelectedItem
            $selectedMethod = $comboMethods.SelectedItem
            $selectedPathObject = $apiPaths.$selectedPath

            if ($null -ne $selectedPathObject -and $null -ne $selectedMethod) {
                # pull the method definition and its params
                $methodObject = $selectedPathObject.$selectedMethod
                $params = Get-ParametersForMethod -methodObject $methodObject

                # build one label+textbox per param
                $y = 10
                foreach ($param in $params) {
                    $label = [System.Windows.Forms.Label]::new()
                    $label.Text = "$($param.name) ($($param.in))"
                    $label.Location = [System.Drawing.Point]::new(10, $y)
                    $label.Width = 300

                    $textbox = [System.Windows.Forms.TextBox]::new()
                    $textbox.Name = "param_$($param.name)"
                    $textbox.Location = [System.Drawing.Point]::new(320, $y)
                    $textbox.Width = 400

                    # when the user types, rebuild the example cURL
                    $textbox.Add_TextChanged({
                            Update-ExampleCurl `
                                -method      $selectedMethod `
                                -rawPath     $selectedPath `
                                -paramDefs   $params `
                                -panelParams $panelParams `
                                -txtExample  $txtExample
                        })

                    $panelParams.Controls.Add($label)
                    $panelParams.Controls.Add($textbox)
                    $y += 30
                }

                # initial example right after method pick
                Update-ExampleCurl `
                    -method      $selectedMethod `
                    -rawPath     $selectedPath `
                    -paramDefs   $params `
                    -panelParams $panelParams `
                    -txtExample  $txtExample
            }
            else {
                # nothing selected , present a default message
                $txtExample.Clear()
                $txtExample.Text = "Select Category → Path → Method to see the example cURL"

            }
        })
    # Submit button logic
    $btnSubmit.Add_Click({
            $selectedPath = $comboPaths.SelectedItem
            $selectedMethod = $comboMethods.SelectedItem
            $selectedPathObject = $apiPaths.$selectedPath

            if ($null -ne $selectedPathObject -and $null -ne $selectedMethod) {
                $methodObject = $selectedPathObject.$selectedMethod
                $params = Get-ParametersForMethod -methodObject $methodObject

                $queryParams = @{}
                $pathParams = @{}
                $bodyParams = @{}
                $headers = @{
                    "Authorization" = "Bearer YOUR_TOKEN_HERE"
                    "Content-Type"  = "application/json"
                }

                foreach ($param in $params) {
                    $textbox = $panelParams.Controls | Where-Object { $_.Name -eq "param_$($param.name)" }
                    if ($textbox -and $textbox.Text -ne "") {
                        switch ($param.in) {
                            "query" { $queryParams[$param.name] = $textbox.Text }
                            "path" { $pathParams[$param.name] = $textbox.Text }
                            "body" { $bodyParams[$param.name] = $textbox.Text }
                            "header" { $headers[$param.name] = $textbox.Text }
                        }
                    }
                }

                $baseUrl = "https://api.mypurecloud.com/api/v2"
                $pathWithReplacements = $selectedPath
                foreach ($key in $pathParams.Keys) {
                    $escapedValue = [uri]::EscapeDataString($pathParams[$key])
                    $pathWithReplacements = $pathWithReplacements -replace "\{$key\}", $escapedValue
                }

                $queryString = if ($queryParams.Count -gt 0) {
                    "?" + ($queryParams.GetEnumerator() | ForEach-Object {
                            [uri]::EscapeDataString($_.Key) + "=" + [uri]::EscapeDataString($_.Value)
                        } -join "&")
                }
                else { "" }

                $fullUrl = $baseUrl + $pathWithReplacements + $queryString
                $body = if ($bodyParams.Count -gt 0) { $bodyParams | ConvertTo-Json -Depth 10 } else { $null }

                try {
                    $response = Invoke-RestMethod -Uri $fullUrl -Method $selectedMethod.ToUpper() -Headers $headers -Body $body -ErrorAction Stop
                    $global:LastResponseText = $response | ConvertTo-Json -Depth 10
                    $resultBox.Text = "Success:`r`n$global:LastResponseText"
                    $btnSave.Enabled = $true
                }
                catch {
                    $global:LastResponseText = ""
                    $resultBox.Text = "Error:`r`n$($_.Exception.Message)"
                    $btnSave.Enabled = $false
                }
            }
        })

    $btnSave.Add_Click({
            if ($global:LastResponseText) {
                $dialog = New-Object System.Windows.Forms.SaveFileDialog
                $dialog.Filter = "JSON Files (*.json)|*.json|All Files (*.*)|*.*"
                $dialog.Title = "Save API Response"
                $dialog.FileName = "API_Response.json"
                if ($dialog.ShowDialog() -eq "OK") {
                    $global:LastResponseText | Out-File -FilePath $dialog.FileName -Encoding utf8
                    [System.Windows.Forms.MessageBox]::Show("Response saved to:`n$($dialog.FileName)", "Saved")
                }
            }
        })

    $form.ShowDialog()
}

# === Run It ===
$JsonPath = "G:\Storage\BenStuff\Development\GitPowershell\GenesysCloudAPIExplorer\GenesysCloudAPIEndpoints.json"
$Paths = Load-APIPathsFromJson -JsonPath $JsonPath
Build-GUI -apiPaths $Paths
