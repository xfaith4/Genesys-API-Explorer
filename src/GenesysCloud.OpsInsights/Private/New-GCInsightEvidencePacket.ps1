### BEGIN FILE: Private\New-GCInsightEvidencePacket.ps1
function New-GCInsightEvidencePacket {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Result
    )

    $metrics = @($Result.Metrics)
    $drilldowns = @($Result.Drilldowns)

    if ($metrics.Count -gt 0) {
        $metricSummary = ($metrics | ForEach-Object {
            $title = if ($_.PSObject.Properties.Name -contains 'title') { $_.title } else { '' }
            $value = if ($_.PSObject.Properties.Name -contains 'value') { $_.value } else { '' }
            "$($title): $($value)"
        }) -join '; '
    }
    else {
        $metricSummary = 'No metrics generated.'
    }

    if ($drilldowns.Count -gt 0) {
        $drilldownSummary = ($drilldowns | ForEach-Object {
            $title = if ($_.PSObject.Properties.Name -contains 'title') { $_.title } else { $_.Id ?? 'drilldown' }
            $count = if ($_.PSObject.Properties.Name -contains 'items') { ($_.items | Measure-Object).Count } else { '' }
            "$title ($count items)"
        }) -join '; '
    }
    else {
        $drilldownSummary = ''
    }

    $idStamp = (Get-Date -Format 'yyyyMMddHHmmss')
    $evidenceId = "{0}-{1}" -f ($Result.Pack.id -replace '[^A-Za-z0-9_\-]', '_'), $idStamp

    return [pscustomobject]@{
        EvidenceId     = $evidenceId
        PackId         = $Result.Pack.id
        PackName       = $Result.Pack.name
        GeneratedUtc   = $Result.GeneratedUtc
        Narrative      = $metricSummary
        DrilldownNotes = $drilldownSummary
        Metrics        = $metrics
        Drilldowns     = $drilldowns
    }
}
### END FILE: Private\New-GCInsightEvidencePacket.ps1
