### BEGIN FILE: Public\Snapshots.ps1
function New-GCSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $safe = ($Name -replace '[^\w\-]+','_').Trim('_')
    [pscustomobject]@{
        Name      = $safe
        CreatedAt = (Get-Date).ToString('o')
        Items     = @()
    }
}

function Save-GCSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Snapshot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $Snapshot | ConvertTo-Json -Depth 80 | Set-Content -Path $Path -Encoding utf8
    Write-Verbose ("Saved snapshot: {0}" -f $Path)
    $Path
}

function Import-GCSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path $Path)) { throw "Snapshot not found: $Path" }
    Get-Content -Path $Path -Raw -Encoding utf8 | ConvertFrom-Json
}
### END FILE: Public\Snapshots.ps1
