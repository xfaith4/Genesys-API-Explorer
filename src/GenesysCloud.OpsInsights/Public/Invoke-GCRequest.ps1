### BEGIN FILE: Public\Invoke-GCRequest.ps1
function Invoke-GCRequest {
    <#
    .SYNOPSIS
    Safe, rate-limit-aware HTTP wrapper for Genesys Cloud API requests.

    .DESCRIPTION
    Centralizes:
      - Base URI + Bearer token handling (from Connect-GCCloud context OR explicit parameters)
      - Querystring building
      - JSON body serialization
      - Retry/backoff for 429 + transient 5xx
      - Optional token refresh via TokenProvider (future-proofing)
      - Optional tracing to a log file (Start-GCTrace)

    .PARAMETER Method
    HTTP method.

    .PARAMETER Path
    API path like '/api/v2/conversations/{id}'. If you provide -Uri (absolute), -Path is ignored.

    .PARAMETER Uri
    Full absolute URI. Prefer -Path for standard Genesys calls.

    .PARAMETER BaseUri
    Optional override base URI (e.g., https://api.usw2.pure.cloud). If not set, uses Connect-GCCloud context.

    .PARAMETER AccessToken
    Optional override bearer token. If not set, uses Connect-GCCloud context.

    .PARAMETER Query
    Hashtable of querystring values. Values are URL-encoded.

    .PARAMETER Body
    Request body object. Serialized as JSON unless -RawBody is used.

    .PARAMETER RawBody
    Raw string body (sent as-is). Use when you already built JSON text.

    .PARAMETER MaxAttempts
    Retry attempts for 429 / transient 5xx failures.

    .PARAMETER MaxBackoffSeconds
    Caps exponential backoff.

    .PARAMETER ReturnMeta
    Returns a wrapper object containing StatusCode/Headers/Url/DurationMs in addition to Response.

    .EXAMPLE
    Connect-GCCloud -RegionDomain 'usw2.pure.cloud' -AccessToken $token
    Invoke-GCRequest -Method GET -Path '/api/v2/users/me'
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET','POST','PUT','PATCH','DELETE')]
        [string]$Method,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Uri')]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$BaseUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken,

        [Parameter()]
        [hashtable]$Query,

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [string]$RawBody,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ContentType = 'application/json',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Accept = 'application/json',

        [Parameter()]
        [ValidateRange(1, 25)]
        [int]$MaxAttempts = 6,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$MaxBackoffSeconds = 60,

        [Parameter()]
        [switch]$ReturnMeta,

        [Parameter()]
        [switch]$DisableRetry
    )

    # Resolve auth from explicit args or module context
    $auth = Resolve-GCAuth -BaseUri $BaseUri -AccessToken $AccessToken

    # Build URL
    $url = $null
    if ($PSCmdlet.ParameterSetName -eq 'Uri') {
        $url = $Uri
    }
    else {
        $url = $auth.BaseUri.TrimEnd('/') + $Path
    }
    # Build querystring (avoid external deps; keep PS 5.1 + 7+ compatible)
    if ($Query -and $Query.Count -gt 0) {
        $ub = [System.UriBuilder]$url

        # Parse existing query into a hashtable
        $existing = @{}
        if (-not [string]::IsNullOrWhiteSpace($ub.Query)) {
            $q = $ub.Query.TrimStart('?')
            foreach ($pair in ($q -split '&')) {
                if ([string]::IsNullOrWhiteSpace($pair)) { continue }
                $kv = $pair -split '=', 2
                $k  = [System.Uri]::UnescapeDataString($kv[0])
                $v  = if ($kv.Count -gt 1) { [System.Uri]::UnescapeDataString($kv[1]) } else { '' }
                $existing[$k] = $v
            }
        }

        # Merge in new parameters (overwrite existing keys)
        foreach ($k in $Query.Keys) {
            if ($null -eq $Query[$k]) { continue }
            $existing[[string]$k] = [string]$Query[$k]
        }

        # Rebuild query string with URL encoding
        $pairs = foreach ($k in $existing.Keys) {
            $ek = [System.Uri]::EscapeDataString([string]$k)
            $ev = [System.Uri]::EscapeDataString([string]$existing[$k])
            "$ek=$ev"
        }

        $ub.Query = ($pairs -join '&')
        $url = $ub.Uri.AbsoluteUri
    }

    # Headers

    $headers = @{
        Authorization = "Bearer $($auth.AccessToken)"
        Accept        = $Accept
    }

    # Build request parameters
    $invokeParams = @{
        Method      = $Method
        Uri         = $url
        Headers     = $headers
        ErrorAction = 'Stop'
    }

    # Serialize body if present
    if ($PSBoundParameters.ContainsKey('RawBody') -and -not [string]::IsNullOrEmpty($RawBody)) {
        $invokeParams.Body = $RawBody
        $invokeParams.ContentType = $ContentType
    }
    elseif ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body -and $Method -ne 'GET') {
        # Convert objects to JSON with a sane depth for Genesys payloads
        if ($Body -is [string]) {
            $invokeParams.Body = $Body
        }
        else {
            $invokeParams.Body = ($Body | ConvertTo-Json -Depth 30)
        }
        $invokeParams.ContentType = $ContentType
    }

    # Internal helper to extract HTTP status + headers when Invoke-RestMethod throws
    function Get-HttpErrorInfo {
        param([Parameter(Mandatory)]$ErrorRecord)

        $statusCode = $null
        $respHeaders = @{}
        $respBody = $null

        $ex = $ErrorRecord.Exception

        # PowerShell 5.1: WebException.Response is the best source of truth
        if ($ex -and $ex.Response) {
            try {
                $httpResp = $ex.Response
                if ($httpResp.StatusCode) {
                    $statusCode = [int]$httpResp.StatusCode
                }

                try {
                    foreach ($h in $httpResp.Headers.AllKeys) {
                        $respHeaders[$h] = $httpResp.Headers[$h]
                    }
                } catch { }

                try {
                    $stream = $httpResp.GetResponseStream()
                    if ($stream) {
                        $reader = New-Object System.IO.StreamReader($stream)
                        $respBody = $reader.ReadToEnd()
                        $reader.Close()
                    }
                } catch { }
            } catch { }
        }
        else {
            # PowerShell 7 sometimes populates ErrorDetails.Message with JSON
            try { $respBody = $ErrorRecord.ErrorDetails.Message } catch { }
        }

        [pscustomobject]@{
            StatusCode = $statusCode
            Headers    = $respHeaders
            Body       = $respBody
        }
    }

    # Retry loop
    $attempt = 0
    $lastError = $null

    while ($attempt -lt $MaxAttempts) {
        $attempt++
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            Write-GCTraceLine ("REQ {0} {1}" -f $Method, $url)

            $response = Invoke-RestMethod @invokeParams

            $sw.Stop()
            Write-GCTraceLine ("RES {0} {1}ms" -f 200, $sw.ElapsedMilliseconds)

            if ($ReturnMeta) {
                return [pscustomobject]@{
                    Url        = $url
                    Method     = $Method
                    StatusCode = 200
                    Headers    = @{}      # Invoke-RestMethod does not return headers; keep consistent shape
                    DurationMs = $sw.ElapsedMilliseconds
                    Attempt    = $attempt
                    Response   = $response
                }
            }

            return $response
        }
        catch {
            $sw.Stop()
            $lastError = $_

            $errInfo = Get-HttpErrorInfo -ErrorRecord $_
            $code = $errInfo.StatusCode

            # Trace (best effort) without leaking bearer tokens
            $codeMsg = if ($code) { $code } else { "ERR" }
            Write-GCTraceLine ("RES {0} {1}ms" -f $codeMsg, $sw.ElapsedMilliseconds)

            # If retry is disabled, fail fast.
            if ($DisableRetry) { throw }

            # Token refresh path (future-proofing): only if we're using context token
            if ($code -eq 401 -and $null -ne $auth.TokenProvider -and -not $PSBoundParameters.ContainsKey('AccessToken')) {
                try {
                    Write-Verbose "401 received; attempting token refresh via TokenProvider..."
                    $newToken = & $auth.TokenProvider
                    if (-not [string]::IsNullOrWhiteSpace($newToken)) {
                        $script:GCContext.AccessToken = $newToken
                        $headers.Authorization = "Bearer $($script:GCContext.AccessToken)"
                        continue
                    }
                }
                catch {
                    # If refresh fails, we fall through and throw.
                }
            }

            # Determine if retryable
            $retryable = $false
            if ($code -eq 429) { $retryable = $true }
            if ($code -ge 500 -and $code -le 599) { $retryable = $true }
            if (-not $code) { $retryable = $true } # network / DNS / etc.

            if (-not $retryable -or $attempt -ge $MaxAttempts) {
                # Add server error body to exception message (without bloating output)
                if ($errInfo.Body -and $errInfo.Body.Length -gt 0) {
                    $msg = "HTTP {0} calling {1} {2}. Body: {3}" -f $code, $Method, $url, ($errInfo.Body.Substring(0, [Math]::Min(1200, $errInfo.Body.Length)))
                    throw $msg
                }
                throw
            }

            # Respect Retry-After when present (seconds or HTTP date)
            $sleepSeconds = $null
            if ($errInfo.Headers.ContainsKey('Retry-After')) {
                $ra = $errInfo.Headers['Retry-After']
                if ($ra -match '^\d+$') {
                    $sleepSeconds = [int]$ra
                }
                else {
                    # If it's a date, convert to seconds from now
                    try {
                        $dt = [DateTimeOffset]::Parse($ra)
                        $delta = ($dt - [DateTimeOffset]::Now).TotalSeconds
                        if ($delta -gt 0) { $sleepSeconds = [int][Math]::Ceiling($delta) }
                    } catch { }
                }
            }

            # Exponential backoff with jitter
            if (-not $sleepSeconds) {
                $base = [Math]::Pow(2, [Math]::Min(6, $attempt))
                $jitter = Get-Random -Minimum 0 -Maximum 1000
                $sleepSeconds = [int][Math]::Min($MaxBackoffSeconds, ($base + ($jitter / 1000)))
            }

            Write-Verbose ("Retrying {0} {1} (attempt {2}/{3}) after {4}s. Last status: {5}" -f $Method, $url, $attempt, $MaxAttempts, $sleepSeconds, $code)
            Start-Sleep -Seconds $sleepSeconds
        }
    }

    throw ("Request failed after {0} attempts. Last error: {1}" -f $MaxAttempts, $lastError)
}
### END FILE: Public\Invoke-GCRequest.ps1
