### BEGIN FILE: Public\Invoke-GCRequest.ps1
function Invoke-GCRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET','POST','PUT','PATCH','DELETE')]
        [string]$Method,

        # Path like '/api/v2/analytics/conversations/details/query' OR full URI
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter()]
        [hashtable]$Query,

        [Parameter()]
        $Body,

        [Parameter()]
        [int]$TimeoutSec = 120,

        # Retry policy
        [Parameter()]
        [int]$MaxAttempts = 6,

        [Parameter()]
        [switch]$Raw
    )

    if (-not $script:GCContext.Connected -or -not $script:GCContext.AccessToken) {
        throw "Not connected. Call Connect-GCCloud first."
    }

    # Build absolute URI if caller supplied a path
    $absUri = if ($Uri -match '^\w+://') { $Uri } else { "$($script:GCContext.BaseUri)$Uri" }

    if ($Query) {
        # Cheap query builder for common cases
        $pairs = $Query.GetEnumerator() | ForEach-Object {
            "{0}={1}" -f [uri]::EscapeDataString($_.Key), [uri]::EscapeDataString([string]$_.Value)
        }
        $qs = ($pairs -join '&')
        if ($absUri -match '\?') { $absUri = "$absUri&$qs" } else { $absUri = "$absUri`?$qs" }
    }

    $headers = @{
        Authorization = "Bearer $($script:GCContext.AccessToken)"
        Accept        = 'application/json'
    }

    $attempt = 0
    $lastErr = $null

    while ($attempt -lt $MaxAttempts) {
        $attempt++

        try {
            $irmParams = @{
                Method      = $Method
                Uri         = $absUri
                Headers     = $headers
                TimeoutSec  = $TimeoutSec
                ErrorAction = 'Stop'
            }

            if ($null -ne $Body -and $Method -in @('POST','PUT','PATCH')) {
                $irmParams.ContentType = 'application/json'
                $irmParams.Body = ($Body | ConvertTo-Json -Depth 50 -Compress)
            }

            # Trace (sanitize token)
            if ($script:GCContext.TraceEnabled -and $script:GCContext.TracePath) {
                $traceObj = [ordered]@{
                    ts     = (Get-Date).ToString('o')
                    method = $Method
                    uri    = $absUri
                    body   = $Body
                    attempt= $attempt
                }
                ($traceObj | ConvertTo-Json -Depth 20 -Compress) | Add-Content -Path $script:GCContext.TracePath -Encoding utf8
            }

            $resp = Invoke-RestMethod @irmParams
            return (if ($Raw) { $resp | ConvertTo-Json -Depth 50 } else { $resp })
        }
        catch {
            $lastErr = $_
            $statusCode = $null
            try { $statusCode = [int]$_.Exception.Response.StatusCode } catch {}

            # Handle 429 / 5xx with backoff
            if ($statusCode -in 429,500,502,503,504) {
                $sleepSec = [math]::Min(60, [math]::Pow(2, $attempt))
                Write-Verbose ("Retry {0}/{1} after {2}s (HTTP {3})" -f $attempt, $MaxAttempts, $sleepSec, $statusCode)
                Start-Sleep -Seconds $sleepSec

                # Optional token refresh hook (future-ready)
                if ($script:GCContext.TokenProvider) {
                    try {
                        $newToken = & $script:GCContext.TokenProvider
                        if ($newToken) { $script:GCContext.AccessToken = $newToken }
                    } catch {
                        # Don't block retries if refresh fails; just keep attempting.
                    }
                }

                continue
            }

            throw
        }
    }

    throw ("Request failed after {0} attempts. Last error: {1}" -f $MaxAttempts, $lastErr)
}
### END FILE: Public\Invoke-GCRequest.ps1
