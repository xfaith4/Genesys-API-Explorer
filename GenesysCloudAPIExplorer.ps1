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

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Genesys Cloud API Explorer"
    $form.Size = New-Object System.Drawing.Size(800, 640)

    $comboGroups = New-Object System.Windows.Forms.ComboBox
    $comboGroups.Location = New-Object System.Drawing.Point(20, 20)
    $comboGroups.Width = 740
    $comboGroups.DropDownStyle = "DropDownList"
    $form.Controls.Add($comboGroups)

    $comboPaths = New-Object System.Windows.Forms.ComboBox
    $comboPaths.Location = New-Object System.Drawing.Point(20, 60)
    $comboPaths.Width = 740
    $comboPaths.DropDownStyle = "DropDownList"
    $form.Controls.Add($comboPaths)

    $comboMethods = New-Object System.Windows.Forms.ComboBox
    $comboMethods.Location = New-Object System.Drawing.Point(20, 100)
    $comboMethods.Width = 740
    $comboMethods.DropDownStyle = "DropDownList"
    $form.Controls.Add($comboMethods)

    $panelParams = New-Object System.Windows.Forms.Panel
    $panelParams.Location = New-Object System.Drawing.Point(20, 140)
    $panelParams.Size = New-Object System.Drawing.Size(740, 280)
    $panelParams.AutoScroll = $true
    $form.Controls.Add($panelParams)

    $btnSubmit = New-Object System.Windows.Forms.Button
    $btnSubmit.Text = "Submit API Call"
    $btnSubmit.Location = New-Object System.Drawing.Point(20, 430)
    $form.Controls.Add($btnSubmit)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save Response"
    $btnSave.Location = New-Object System.Drawing.Point(150, 430)
    $btnSave.Enabled = $false
    $form.Controls.Add($btnSave)

    $resultBox = New-Object System.Windows.Forms.TextBox
    $resultBox.Multiline = $true
    $resultBox.ScrollBars = "Vertical"
    $resultBox.ReadOnly = $true
    $resultBox.Location = New-Object System.Drawing.Point(20, 470)
    $resultBox.Size = New-Object System.Drawing.Size(740, 100)
    $form.Controls.Add($resultBox)

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
    })

    $comboPaths.Add_SelectedIndexChanged({
        $comboMethods.Items.Clear()
        $panelParams.Controls.Clear()

        $selectedPath = $comboPaths.SelectedItem
        $selectedPathObject = ($apiPaths.PSObject.Properties | Where-Object { $_.Name -eq $selectedPath }).Value

        if ($null -ne $selectedPathObject) {
            $methods = Get-MethodsForPath -pathObject $selectedPathObject
            $comboMethods.Items.AddRange($methods)
        }
    })

    $comboMethods.Add_SelectedIndexChanged({
        $panelParams.Controls.Clear()

        $selectedPath = $comboPaths.SelectedItem
        $selectedMethod = $comboMethods.SelectedItem
        $selectedPathObject = ($apiPaths.PSObject.Properties | Where-Object { $_.Name -eq $selectedPath }).Value

        if ($null -ne $selectedPathObject -and $null -ne $selectedMethod) {
            $methodObject = $selectedPathObject.$selectedMethod
            $params = Get-ParametersForMethod -methodObject $methodObject

            if ($params) {
                $y = 10
                foreach ($param in $params) {
                    $label = New-Object System.Windows.Forms.Label
                    $label.Text = "$($param.name) ($($param.in))"
                    $label.Location = New-Object System.Drawing.Point(10, $y)
                    $label.Width = 300

                    $textbox = New-Object System.Windows.Forms.TextBox
                    $textbox.Name = "param_$($param.name)"
                    $textbox.Location = New-Object System.Drawing.Point(320, $y)
                    $textbox.Width = 400

                    $panelParams.Controls.Add($label)
                    $panelParams.Controls.Add($textbox)
                    $y += 30
                }
            }
        }
    })

    $btnSubmit.Add_Click({
        $selectedPath = $comboPaths.SelectedItem
        $selectedMethod = $comboMethods.SelectedItem
        $selectedPathObject = ($apiPaths.PSObject.Properties | Where-Object { $_.Name -eq $selectedPath }).Value

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
                        "query"  { $queryParams[$param.name] = $textbox.Text }
                        "path"   { $pathParams[$param.name] = $textbox.Text }
                        "body"   { $bodyParams[$param.name] = $textbox.Text }
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
            } else { "" }

            $fullUrl = $baseUrl + $pathWithReplacements + $queryString
            $body = if ($bodyParams.Count -gt 0) { $bodyParams | ConvertTo-Json -Depth 10 } else { $null }

            try {
                $response = Invoke-RestMethod -Uri $fullUrl -Method $selectedMethod.ToUpper() -Headers $headers -Body $body -ErrorAction Stop
                $global:LastResponseText = $response | ConvertTo-Json -Depth 10
                $resultBox.Text = "Success:`r`n$global:LastResponseText"
                $btnSave.Enabled = $true
            } catch {
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
$JsonPath = "G:\Storage\BenStuff\Development\OpenAI\OpenAI_Refiner\Sessions\20250727_175519_genesys_cloud_api_endpoints\GenesysCloudAPIEndpoints.json"
$Paths = Load-APIPathsFromJson -JsonPath $JsonPath
Build-GUI -apiPaths $Paths
