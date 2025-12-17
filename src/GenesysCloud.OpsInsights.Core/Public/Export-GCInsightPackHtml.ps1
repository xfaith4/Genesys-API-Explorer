### BEGIN FILE: src\GenesysCloud.OpsInsights.Core\Public\Export-GCInsightPackHtml.ps1
function Export-GCInsightPackHtml {
    <#
      .SYNOPSIS
        Exports an Insight Pack execution result to a portable HTML report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $dir = [System.IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $packId   = [string]$Result.Pack.id
    $packName = [string]$Result.Pack.name
    $genUtc   = [string]$Result.GeneratedUtc

    $metrics = @($Result.Metrics)
    $steps   = @($Result.Steps)
    $encode  = [System.Net.WebUtility]::HtmlEncode

    $style = @"
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; }
h1 { margin-bottom: 4px; }
.meta { color: #666; margin-bottom: 16px; }
.card { border: 1px solid #ddd; border-radius: 10px; padding: 12px 14px; margin: 12px 0; }
.kv { display: grid; grid-template-columns: 180px 1fr; gap: 6px 12px; }
table { border-collapse: collapse; width: 100%; margin-top: 8px; }
th, td { border-bottom: 1px solid #eee; padding: 8px; text-align: left; vertical-align: top; }
th { background: #fafafa; }
</style>
"@

    $html = New-Object System.Text.StringBuilder
    [void]$html.AppendLine("<html><head><meta charset='utf-8'/>$style</head><body>")
    [void]$html.AppendLine("<h1>$($encode($packName))</h1>")
    [void]$html.AppendLine("<div class='meta'>Pack: <b>$($encode($packId))</b> &nbsp; Generated (UTC): <b>$($encode($genUtc))</b></div>")

    # Parameters
    [void]$html.AppendLine("<div class='card'><h2>Parameters</h2><div class='kv'>")
    foreach ($k in ($Result.Parameters.Keys | Sort-Object)) {
        $v = $Result.Parameters[$k]
        [void]$html.AppendLine("<div><b>$($encode($k))</b></div><div>$($encode([string]$v))</div>")
    }
    [void]$html.AppendLine("</div></div>")

    # Metrics
    [void]$html.AppendLine("<div class='card'><h2>Metrics</h2>")
    if ($metrics.Count -eq 0) {
        [void]$html.AppendLine("<div>(No metrics produced.)</div>")
    } else {
        foreach ($m in $metrics) {
            $title = [string]$m.title
            $value = [string]$m.value
            [void]$html.AppendLine("<h3>$($encode($title))</h3>")
            if ($value) {
                [void]$html.AppendLine("<div><b>Value:</b> $($encode($value))</div>")
            }

            if ($m.PSObject.Properties.Name -contains 'items' -and $null -ne $m.items) {
                $items = @($m.items)
                if ($items.Count -gt 0) {
                    $cols = @($items[0].PSObject.Properties.Name)
                    [void]$html.AppendLine("<table><thead><tr>")
                    foreach ($c in $cols) {
                        [void]$html.AppendLine("<th>$($encode($c))</th>")
                    }
                    [void]$html.AppendLine("</tr></thead><tbody>")
                    foreach ($row in $items) {
                        [void]$html.AppendLine("<tr>")
                        foreach ($c in $cols) {
                            $cell = $row.PSObject.Properties[$c].Value
                            [void]$html.AppendLine("<td>$($encode([string]$cell))</td>")
                        }
                        [void]$html.AppendLine("</tr>")
                    }
                    [void]$html.AppendLine("</tbody></table>")
                }
            }
        }
    }
    [void]$html.AppendLine("</div>")

    # Steps
    [void]$html.AppendLine("<div class='card'><h2>Pipeline Steps</h2>")
    if ($steps.Count -gt 0) {
        $table = $steps | Select-Object Id,Type,DurationMs,StartedUtc,EndedUtc |
            ConvertTo-Html -Fragment -As Table
        $table | ForEach-Object { [void]$html.AppendLine($_) }
    } else {
        [void]$html.AppendLine("<div>(No step timing captured.)</div>")
    }
    [void]$html.AppendLine("</div>")

    [void]$html.AppendLine("</body></html>")

    $html.ToString() | Set-Content -LiteralPath $fullPath -Encoding utf8
    return $fullPath
}
### END FILE
