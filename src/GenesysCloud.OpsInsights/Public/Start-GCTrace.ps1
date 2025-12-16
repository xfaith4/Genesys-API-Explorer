### BEGIN FILE: Public\Start-GCTrace.ps1
function Start-GCTrace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $script:GCContext.TraceEnabled = $true
    $script:GCContext.TracePath    = $Path

    # Create/overwrite
    "" | Set-Content -Path $Path -Encoding utf8
    Write-Verbose ("Tracing enabled: {0}" -f $Path)
}

function Stop-GCTrace {
    [CmdletBinding()]
    param()

    $script:GCContext.TraceEnabled = $false
    Write-Verbose "Tracing disabled."
}
### END FILE: Public\Start-GCTrace.ps1
