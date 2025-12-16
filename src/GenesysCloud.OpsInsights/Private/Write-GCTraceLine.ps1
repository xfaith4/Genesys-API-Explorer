### BEGIN FILE: Private\Write-GCTraceLine.ps1
function Write-GCTraceLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        if (-not $script:GCContext.TraceEnabled) { return }
        if ([string]::IsNullOrWhiteSpace($script:GCContext.TracePath)) { return }

        $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
        $line = "[{0}] {1}" -f $ts, $Message

        Add-Content -Path $script:GCContext.TracePath -Value $line -Encoding utf8
    }
    catch {
        # Tracing must never break normal execution.
    }
}
### END FILE: Private\Write-GCTraceLine.ps1
