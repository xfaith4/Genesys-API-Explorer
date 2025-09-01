function Load-APIPathsFromJson {
    param([string]$JsonPath)
    $json = Get-Content $JsonPath -Raw | ConvertFrom-Json
    return $json.'openapi-cache-https---api-mypurecloud-com-api-v2-docs-swagger'.paths
}

function Get-MethodsForPath {
    param($pathObject)
    return $pathObject.PSObject.Properties.Name
}

function Get-ParametersForMethod {
    param($methodObject)
    return $methodObject.parameters
}

function Invoke-GenesysApi {
    param(
        [string]$BaseUrl,
        [string]$Path,
        [string]$Method,
        [hashtable]$PathParams,
        [hashtable]$QueryParams,
        [hashtable]$BodyParams,
        [hashtable]$Headers,
        [string]$BodyType = "application/json"
    )

    $pathWithReplacements = $Path
    foreach ($key in $PathParams.Keys) {
        $escapedValue = [uri]::EscapeDataString($PathParams[$key])
        $pathWithReplacements = $pathWithReplacements -replace "\{$key\}", $escapedValue
    }

    $queryString = if ($QueryParams.Count -gt 0) {
        "?" + ($QueryParams.GetEnumerator() | ForEach-Object {
            [uri]::EscapeDataString($_.Key) + "=" + [uri]::EscapeDataString($_.Value)
        } -join "&")
    } else { "" }

    $url = $BaseUrl + $pathWithReplacements + $queryString

    $bodyString = $null
    $body = $null
    switch ($BodyType) {
        "application/json" {
            if ($BodyParams.Count -gt 0) {
                $bodyString = $BodyParams | ConvertTo-Json -Depth 10
                $body = $bodyString
            }
        }
        "application/x-www-form-urlencoded" {
            if ($BodyParams.Count -gt 0) {
                $bodyString = ($BodyParams.GetEnumerator() | ForEach-Object {
                    [uri]::EscapeDataString($_.Key) + "=" + [uri]::EscapeDataString($_.Value)
                } -join "&")
                $body = $bodyString
            }
        }
        "multipart/form-data" {
            $boundary = [System.Guid]::NewGuid().ToString()
            $Headers["Content-Type"] = "multipart/form-data; boundary=$boundary"
            $stream = New-Object System.IO.MemoryStream
            $writer = New-Object System.IO.StreamWriter($stream)
            foreach ($key in $BodyParams.Keys) {
                $writer.WriteLine("--$boundary")
                $writer.WriteLine("Content-Disposition: form-data; name=\"$key\"")
                $writer.WriteLine()
                $writer.WriteLine($BodyParams[$key])
            }
            $writer.WriteLine("--$boundary--")
            $writer.Flush()
            $stream.Position = 0
            $body = $stream
            $bodyString = "[multipart/form-data body]"
        }
    }

    $response = Invoke-RestMethod -Uri $url -Method $Method.ToUpper() -Headers $Headers -Body $body -ErrorAction Stop
    return [pscustomobject]@{ Url = $url; Response = $response; BodyString = $bodyString }
}
