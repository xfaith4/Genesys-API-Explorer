### BEGIN FILE: Private\Get-TemplatedObject.ps1
function Get-TemplatedObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Template,

        [Parameter()]
        [hashtable]$Parameters
    )

    # Very small templating helper:
    # - Replace '{{paramName}}' tokens inside strings
    # - Return a hashtable/array/object suitable for ConvertTo-Json
    $json = ($Template | ConvertTo-Json -Depth 80)

    foreach ($k in ($Parameters.Keys | Sort-Object -Descending)) {
        $token = "{{{0}}}" -f $k
        $json = $json -replace [regex]::Escape($token), [string]$Parameters[$k]
    }

    $json | ConvertFrom-Json
}
### END FILE: Private\Get-TemplatedObject.ps1
