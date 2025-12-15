### BEGIN FILE: Public\Invoke-GCInsightPack.ps1
function Invoke-GCInsightPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PackPath,

        [Parameter()]
        [hashtable]$Parameters,

        # Optional: add raw inputs/outputs to a snapshot object for reproducibility
        [Parameter()]
        $Snapshot
    )

    if (-not (Test-Path $PackPath)) { throw "Pack not found: $PackPath" }

    $pack = Get-Content -Path $PackPath -Raw -Encoding utf8 | ConvertFrom-Json

    # Minimal runner: execute pack-defined steps in order.
    # "Done right" runner will add: dependency graph, caching, paging guards, and standardized drilldowns.
    $ctx = [ordered]@{
        Pack       = $pack
        Parameters = ($Parameters ?? @{})
        Data       = @{}
        Metrics    = @()
        Drilldowns = @()
    }

    foreach ($step in $pack.pipeline) {
        $type = $step.type

        switch ($type) {
            'gcRequest' {
                $uri = [string]$step.uri
                $method = [string]$step.method
                $body = $null

                if ($step.bodyTemplate) {
                    $body = (Get-TemplatedObject -Template $step.bodyTemplate -Parameters $ctx.Parameters)
                }

                $resp = Invoke-GCRequest -Method $method -Uri $uri -Body $body -Query $step.query

                $ctx.Data[$step.id] = $resp

                if ($Snapshot) {
                    $Snapshot.Items += [pscustomobject]@{
                        id     = $step.id
                        type   = $type
                        method = $method
                        uri    = $uri
                        query  = $step.query
                        body   = $body
                        data   = $resp
                    }
                }
            }

            'compute' {
                # compute steps run a scriptblock string (controlled by pack authors you trust)
                $sb = [scriptblock]::Create([string]$step.script)
                $result = & $sb $ctx
                $ctx.Data[$step.id] = $result
            }

            'metric' {
                $sb = [scriptblock]::Create([string]$step.script)
                $metric = & $sb $ctx
                $ctx.Metrics += $metric
            }

            default {
                throw "Unknown step type: $type"
            }
        }
    }

    [pscustomobject]@{
        PackId   = $pack.id
        PackName = $pack.name
        Metrics  = $ctx.Metrics
        Data     = $ctx.Data
        Snapshot = $Snapshot
    }
}
### END FILE: Public\Invoke-GCInsightPack.ps1
