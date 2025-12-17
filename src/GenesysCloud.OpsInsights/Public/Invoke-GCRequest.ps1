### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Invoke-GCRequest.ps1
function Invoke-GCRequest {
    <#
      .SYNOPSIS
        Canonical Genesys Cloud REST transport (mockable; PS 5.1 + 7+).
      .DESCRIPTION
        - Supports offline dev via Set-GCInvoker (fixtures/mocks)
        - Defaults to api.usw2.pure.cloud when no context/baseuri supplied
        - Uses $global:AccessToken automatically if present
        - Retries transient failures and honors Retry-After for 429s
        - Defensive error parsing (does not assume .Response exists)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET','POST','PUT','PATCH','DELETE')]
        [string]$Method,

        [Parameter()]
        [string]$Uri,

        [Parameter()]
        [string]$Path,

        [Parameter()]
        [string]$BaseUri,

        [Parameter()]
        [string]$AccessToken,

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [hashtable]$Headers,

        [Parameter()]
        [int]$TimeoutSec = 100,

        [Parameter()]
        [int]$MaxAttempts = 6
    )

    # -------- Context / Defaults --------
    $ctx = $script:GCContext

    if (-not $BaseUri) {
        if ($ctx -and $ctx.PSObject.Properties.Name -contains 'ApiBaseUri' -and $ctx.ApiBaseUri) {
            $BaseUri = $ctx.ApiBaseUri
        } elseif ($ctx -and $ctx.PSObject.Properties.Name -contains 'BaseUri' -and $ctx.BaseUri) {
            $BaseUri = $ctx.BaseUri
        } else {
            # Default to primary region for Ben's org
            $BaseUri = 'https://api.usw2.pure.cloud'
        }
    }

    # Prefer explicit token, then global token, then context, then token provider
    if (-not $AccessToken -and $global:AccessToken) {
        $AccessToken = $global:AccessToken
    }
    if (-not $AccessToken -and $ctx -and $ctx.PSObject.Properties.Name -contains 'AccessToken' -and $ctx.AccessToken) {
        $AccessToken = $ctx.AccessToken
    }
    if (-not $AccessToken -and $ctx -and $ctx.PSObject.Properties.Name -contains 'TokenProvider' -and $ctx.TokenProvider) {
        try { $AccessToken = & $ctx.TokenProvider } catch { }
    }

    if (-not $Uri) {
        if (-not $Path) { throw "Invoke-GCRequest requires -Uri or -Path." }
        $Uri = ($BaseUri.TrimEnd('/') + '/' + $Path.TrimStart('/'))
    }

    if (-not $Headers) { $Headers = @{} }

    if ($AccessToken -and -not $Headers.ContainsKey('Authorization')) {
        $Headers['Authorization'] = "Bearer $($AccessToken)"
    }
    if (-not $Headers.ContainsKey('Accept')) { $Headers['Accept'] = 'application/json' }
    if ($Body -and -not $Headers.ContainsKey('Content-Type')) { $Headers['Content-Type'] = 'application/json' }

    $payload = $null
    if ($Body) {
        if ($Body -is [string]) { $payload = $Body }
        else { $payload = ($Body | ConvertTo-Json -Depth 50) }
    }

    function Get-GCTraceHeaders {
        param([hashtable]$Headers)

        if (-not $Headers) { return '<none>' }

        $pairs = foreach ($key in ($Headers.Keys | Sort-Object)) {
            $value = $Headers[$key]
            if ($key -match '^(Authorization|X-Auth-Token)$') {
                $value = 'REDACTED'
            }
            "$key=$value"
        }

        return ($pairs -join '; ')
    }

    function Get-GCTraceBody {
        param([string]$Body)

        if (-not $Body) { return '<empty>' }
        if ($Body.Length -gt 512) {
            return ($Body.Substring(0, 512) + '...')
        }

        return $Body
    }

    function Get-GCErrorInfo {
        param([Parameter(Mandatory)][System.Exception]$Exception)

        $info = [ordered]@{
            Message    = $Exception.Message
            StatusCode = $null
            Reason     = $null
            Body       = $null
            Headers    = $null
        }

        $resp = $null
        try { $resp = $Exception.Response } catch { }

        if ($resp) {
            try { $info.StatusCode = [int]$resp.StatusCode } catch { }
            try { $info.Reason     = [string]$resp.StatusDescription } catch { }

            try {
                $info.Headers = @{}
                foreach ($k in $resp.Headers.Keys) { $info.Headers[$k] = $resp.Headers[$k] }
            } catch { }

            try {
                $stream = $resp.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream)
                    $info.Body = $reader.ReadToEnd()
                    $reader.Close()
                }
            } catch { }
        }

        return [pscustomobject]$info
    }

    # -------- Mockable invoker seam --------
    if (-not $script:GCInvoker) {
        $script:GCInvoker = {
            param([hashtable]$Request)

            $irmSplat = @{
                Method      = $Request.Method
                Uri         = $Request.Uri
                Headers     = $Request.Headers
                TimeoutSec  = $Request.TimeoutSec
                ErrorAction = 'Stop'
            }
            if ($Request.Body) { $irmSplat.Body = $Request.Body }

            Invoke-RestMethod @irmSplat
        }
    }

    # -------- Execute w/ retries --------
    $attempt = 0
    $lastErr = $null

    while ($attempt -lt $MaxAttempts) {
        $attempt++

        if ($script:GCContext.TraceEnabled) {
            $traceHeaders = Get-GCTraceHeaders -Headers $Headers
            $traceBody    = Get-GCTraceBody -Body $payload
            Write-GCTraceLine -Message ("[Attempt {0}] Requesting {1} {2} Headers: {3} Body: {4}" -f $attempt, $Method, $Uri, $traceHeaders, $traceBody)
        }

        try {
            $req = @{
                Method     = $Method
                Uri        = $Uri
                Headers    = $Headers
                Body       = $payload
                TimeoutSec = $TimeoutSec
            }

            $response = (& $script:GCInvoker $req)

            if ($script:GCContext.TraceEnabled) {
                Write-GCTraceLine -Message ("[Attempt {0}] Request succeeded for {1} {2}" -f $attempt, $Method, $Uri)
            }

            return $response
        }
        catch {
            $errInfo = Get-GCErrorInfo -Exception $_.Exception
            $lastErr = $errInfo
            $code = $errInfo.StatusCode

            if ($script:GCContext.TraceEnabled) {
                $statusText = if ($code) { $code } else { 'unknown' }
                Write-GCTraceLine -Message ("[Attempt {0}] Request failed for {1} {2} Status={3} Message={4}" -f $attempt, $Method, $Uri, $statusText, $errInfo.Message)
            }

            # 429: honor Retry-After when present
            if ($code -eq 429 -and $errInfo.Headers -and $errInfo.Headers['Retry-After']) {
                $ra = 0
                [int]::TryParse($errInfo.Headers['Retry-After'], [ref]$ra) | Out-Null
                if ($ra -gt 0) { Start-Sleep -Seconds $ra }
                else { Start-Sleep -Seconds ([Math]::Min(30, (2 * $attempt))) }
                continue
            }

            # Retry 5xx or unknown (network)
            if (($code -ge 500 -and $code -le 599) -or ($null -eq $code)) {
                Start-Sleep -Seconds ([Math]::Min(30, (2 * $attempt)))
                continue
            }

            $detail = ($errInfo | ConvertTo-Json -Depth 10)
            throw "GC request failed (attempt $($attempt) of $($MaxAttempts)) for $($Method) $($Uri). Details: $($detail)"
        }
    }

    $final = ($lastErr | ConvertTo-Json -Depth 10)
    throw "GC request failed after $($MaxAttempts) attempts for $($Method) $($Uri). Last error: $($final)"
}
### END FILE
