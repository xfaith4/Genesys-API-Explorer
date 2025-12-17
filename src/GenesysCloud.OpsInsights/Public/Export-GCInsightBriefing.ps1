### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Export-GCInsightBriefing.ps1
function Export-GCInsightBriefing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,

        [Parameter()]
        [string]$Directory,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    if (-not $Directory) {
        $Directory = (Get-Location).ProviderPath
    }

    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    }

    $safePackId = ($Result.Pack.id -replace '[^A-Za-z0-9_\-]', '_')
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $baseName = if ($Name) { $Name } else { "{0}_{1}" -f $safePackId, $stamp }

    $snapshotPath = Join-Path -Path $Directory -ChildPath ("{0}.snapshot.json" -f $baseName)
    $htmlPath     = Join-Path -Path $Directory -ChildPath ("{0}.html" -f $baseName)
    $excelPath    = Join-Path -Path $Directory -ChildPath ("{0}.xlsx" -f $baseName)

    $exportedSnapshot = Export-GCInsightPackSnapshot -Result $Result -Path $snapshotPath -Force:$Force
    $exportedHtml     = Export-GCInsightPackHtml -Result $Result -Path $htmlPath
    $excelInfo        = Export-GCInsightPackExcel -Result $Result -Path $excelPath -Force:$Force

    return [pscustomobject]@{
        PackId       = $Result.Pack.id
        SnapshotPath = $exportedSnapshot
        HtmlPath     = $exportedHtml
        ExcelInfo    = $excelInfo
        Evidence     = $Result.Evidence
    }
}
### END FILE: src\GenesysCloud.OpsInsights\Public/Export-GCInsightBriefing.ps1
