### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Invoke-GCInsightPack.ps1
function Invoke-GCInsightPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackPath,

        [Parameter()]
        [hashtable]$Parameters
    )

    if (-not (Test-Path -LiteralPath $PackPath)) {
        throw "Insight pack not found: $PackPath"
    }

    if ($null -eq $Parameters) { $Parameters = @{} }

    $packJson = Get-Content -LiteralPath $PackPath -Raw
    $pack = $packJson | ConvertFrom-Json

    $resolvedParameters = Get-GCInsightPackParameters -Pack $pack -Overrides $Parameters

    $ctx = [pscustomobject]@{
        Pack       = $pack
        Parameters = $resolvedParameters
        Data       = [ordered]@{}
        Metrics    = New-Object System.Collections.ArrayList
        Drilldowns = New-Object System.Collections.ArrayList
        Steps      = New-Object System.Collections.ArrayList
        GeneratedUtc = (Get-Date).ToUniversalTime()
    }

    foreach ($step in @($pack.pipeline)) {
        if (-not $step.id) { throw "Insight pack step missing 'id' property." }

        $log = New-GCInsightStepLog -StepDefinition $step
        $started = Get-Date

        try {
            switch ($step.type.ToLowerInvariant()) {
                'gcrequest' {
                    $method = if ($step.method) { $step.method.ToUpper() } else { 'GET' }
                    $pathTemplate = if ($step.uri) { $step.uri } elseif ($step.path) { $step.path } else { throw "gcRequest step '$($step.id)' requires 'uri' or 'path'." }
                    $resolvedPath = Resolve-GCInsightTemplateString -Template $pathTemplate -Parameters $ctx.Parameters
                    $querySuffix = Resolve-GCInsightPackQueryString -QueryTemplate $step.query -Parameters $ctx.Parameters

                    $headers = Resolve-GCInsightPackHeaders -HeadersTemplate $step.headers -Parameters $ctx.Parameters

                    $body = $null
                    if ($step.bodyTemplate) {
                        $body = Get-TemplatedObject -Template $step.bodyTemplate -Parameters $ctx.Parameters
                    }

                    $requestSplat = @{
                        Method = $method
                        Headers = $headers
                    }

                    $pathWithQuery = $resolvedPath + $querySuffix
                    if ($pathWithQuery -match '^https?://') {
                        $requestSplat.Uri = $pathWithQuery
                    }
                    else {
                        $requestSplat.Path = $pathWithQuery
                    }

                    if ($body) {
                        $requestSplat.Body = $body
                    }

                    $response = Invoke-GCRequest @requestSplat
                    $ctx.Data[$step.id] = $response
                    $log.ResultSummary = "HTTP $method → $pathWithQuery (received status: $($response.statusCode -or 'OK'))"
                }

                'compute' {
                    if (-not $step.script) { throw "Compute step '$($step.id)' requires a script block." }
                    $scriptBlock = [scriptblock]::Create($step.script)
                    $result = & $scriptBlock $ctx
                    $ctx.Data[$step.id] = $result
                    $log.ResultSummary = "Computed '$($step.id)'"
                }

                'metric' {
                    if (-not $step.script) { throw "Metric step '$($step.id)' requires a script block." }
                    $scriptBlock = [scriptblock]::Create($step.script)
                    $metric = & $scriptBlock $ctx
                    if ($metric) {
                        $ctx.Metrics.Add($metric) | Out-Null
                        $title = if ($metric.PSObject.Properties.Name -contains 'title') { $metric.title } else { $step.id }
                        $log.ResultSummary = "Metric '$title'"
                    }
                }

                'drilldown' {
                    if (-not $step.script) { throw "Drilldown step '$($step.id)' requires a script block." }
                    $scriptBlock = [scriptblock]::Create($step.script)
                    $drilldown = & $scriptBlock $ctx
                    if ($drilldown) {
                        $ctx.Drilldowns.Add($drilldown) | Out-Null
                        $log.ResultSummary = "Drilldown '$($step.id)'"
                    }
                }

                default {
                    throw "Unsupported insight pack step type: $($step.type)"
                }
            }

            $log.Status = 'Success'
        }
        catch {
            $log.Status = 'Failed'
            $log.ErrorMessage = $_.Exception.Message
            throw
        }
        finally {
            $ended = Get-Date
            $log.EndedUtc = $ended.ToUniversalTime()
            $log.DurationMs = [math]::Round(($ended - $started).TotalMilliseconds, 0)
            $ctx.Steps.Add($log) | Out-Null
        }
    }

    $result = [pscustomobject]@{
        Pack        = $pack
        Parameters  = $ctx.Parameters
        Data        = $ctx.Data
        Metrics     = $ctx.Metrics
        Drilldowns  = $ctx.Drilldowns
        Steps       = $ctx.Steps
        GeneratedUtc= $ctx.GeneratedUtc
    }

    $result | Add-Member -MemberType NoteProperty -Name Evidence -Value (New-GCInsightEvidencePacket -Result $result) -Force

    return $result
}
### END FILE: src\GenesysCloud.OpsInsights\Public\Invoke-GCInsightPack.ps1
