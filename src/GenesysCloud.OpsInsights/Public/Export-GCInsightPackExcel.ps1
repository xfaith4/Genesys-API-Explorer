### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Export-GCInsightPackExcel.ps1
function Export-GCInsightPackExcel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,

        [Parameter()]
        [string]$Path,

        [Parameter()]
        [switch]$Force
    )

    if (-not $Path) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $Path = Join-Path -Path (Get-Location).Path -ChildPath ("GCInsights_{0}.xlsx" -f $stamp)
    }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $dir = [System.IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if ($fullPath.ToLower().EndsWith('.csv')) {
        $fullPath = [System.IO.Path]::ChangeExtension($fullPath, 'xlsx')
    }

    $metricsRows = foreach ($metric in @($Result.Metrics)) {
        [pscustomobject]@{
            Title   = if ($metric.PSObject.Properties.Name -contains 'title') { $metric.title } else { $null }
            Value   = if ($metric.PSObject.Properties.Name -contains 'value') { $metric.value } else { $null }
            Items   = if ($metric.PSObject.Properties.Name -contains 'items') { @($metric.items).Count } else { 0 }
            Details = if ($metric.PSObject.Properties.Name -contains 'items') {
                ($metric.items | ConvertTo-Json -Depth 4)
            } else { $null }
        }
    }

    $stepsRows = foreach ($step in @($Result.Steps)) {
        [pscustomobject]@{
            Id           = $step.Id
            Type         = $step.Type
            Status       = $step.Status
            DurationMs   = $step.DurationMs
            StartedUtc   = $step.StartedUtc
            EndedUtc     = $step.EndedUtc
            ResultSummary= $step.ResultSummary
            ErrorMessage = $step.ErrorMessage
        }
    }

    $paths = @()
    $primaryPath = $fullPath
    $format = 'Xlsx'

    $hasImportExcel = $false
    try { $hasImportExcel = [bool](Get-Module -ListAvailable -Name ImportExcel) } catch { $hasImportExcel = $false }

    if ($hasImportExcel) {
        Import-Module ImportExcel -ErrorAction Stop

        $metricsRows | Export-Excel -Path $primaryPath `
            -WorksheetName 'Metrics' `
            -TableName 'Metrics' `
            -AutoSize `
            -FreezeTopRow

        $stepsRows | Export-Excel -Path $primaryPath `
            -WorksheetName 'Steps' `
            -TableName 'Steps' `
            -AutoSize `
            -FreezeTopRow `
            -AppendSheet
        $paths += $primaryPath
    }
    else {
        $format = 'Csv'
        $metricsCsv = [System.IO.Path]::ChangeExtension($primaryPath, 'Metrics.csv')
        $stepsCsv = [System.IO.Path]::ChangeExtension($primaryPath, 'Steps.csv')

        foreach ($file in @($metricsCsv, $stepsCsv)) {
            if ((Test-Path -LiteralPath $file) -and (-not $Force)) {
                throw "File already exists: $($file). Use -Force to overwrite."
            }
        }

        $metricsRows | Export-Csv -LiteralPath $metricsCsv -NoTypeInformation -Encoding utf8
        $stepsRows   | Export-Csv -LiteralPath $stepsCsv   -NoTypeInformation -Encoding utf8

        $primaryPath = $metricsCsv
        $paths = @($metricsCsv, $stepsCsv)
    }

    return [pscustomobject]@{
        Format      = $format
        PrimaryPath = $primaryPath
        Paths       = $paths
    }
}
### END FILE: src\GenesysCloud.OpsInsights\Public/Export-GCInsightPackExcel.ps1
