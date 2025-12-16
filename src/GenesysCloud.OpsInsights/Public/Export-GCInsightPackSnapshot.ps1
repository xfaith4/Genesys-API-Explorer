### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Export-GCInsightPackSnapshot.ps1
function Export-GCInsightPackSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Result,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [switch]$Force
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $dir = [System.IO.Path]::GetDirectoryName($fullPath)
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if ((Test-Path -LiteralPath $fullPath) -and (-not $Force)) {
        throw "Snapshot file already exists: $($fullPath). Use -Force to overwrite."
    }

    $json = $Result | ConvertTo-Json -Depth 12
    $json | Set-Content -LiteralPath $fullPath -Encoding utf8
    return $fullPath
}
### END FILE: src\GenesysCloud.OpsInsights\Public\Export-GCInsightPackSnapshot.ps1
