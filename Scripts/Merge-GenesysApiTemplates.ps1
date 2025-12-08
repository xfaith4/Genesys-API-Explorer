### BEGIN: Merge-GenesysApiTemplates
[CmdletBinding()]
param(
    # Auto-generated catalog (the big file you just produced)
    [Parameter(Mandatory=$true)]
    [string]$GeneratedPath,

    # Smaller JSON with your hand-crafted templates (with bodies, good names, etc.)
    [Parameter(Mandatory=$true)]
    [string]$CuratedPath,

    # Output the merged result here
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\GenesysApiTemplates.merged.json"
)

# Load generated templates
if (-not (Test-Path -LiteralPath $GeneratedPath)) {
    throw "Generated template file not found at '$GeneratedPath'."
}
$generatedJson = Get-Content -LiteralPath $GeneratedPath -Raw
$generated     = $generatedJson | ConvertFrom-Json

# Load curated templates
if (-not (Test-Path -LiteralPath $CuratedPath)) {
    throw "Curated template file not found at '$CuratedPath'."
}
$curatedJson = Get-Content -LiteralPath $CuratedPath -Raw
$curated     = $curatedJson | ConvertFrom-Json

# Hashtable keyed by "METHOD PATH" to dedupe
$templateMap = @{}

# Helper to build a stable key for a template
function Get-TemplateKey {
    param(
        [Parameter(Mandatory=$true)]
        $Template
    )

    $method = ($Template.Method  | ForEach-Object { $_.ToString().ToUpperInvariant() })
    $path   = ($Template.Path    | ForEach-Object { $_.ToString() })

    if (-not $method -or -not $path) {
        throw "Template is missing Method or Path: $($Template | ConvertTo-Json -Depth 3)"
    }

    return "{0} {1}" -f $method, $path
}

# 1) Seed with generated templates (broad coverage)
foreach ($tpl in $generated) {
    $key = Get-TemplateKey -Template $tpl
    $templateMap[$key] = $tpl  # last write wins; for generated we don't care
}

# 2) Overlay curated templates (better bodies, better names, etc.)
foreach ($tpl in $curated) {
    $key = Get-TemplateKey -Template $tpl
    $templateMap[$key] = $tpl  # curated overrides generated
}

# Sort for sanity in the output (by Group, then Path, then Method)
$merged =
    $templateMap.Values |
    Sort-Object Group, Path, Method

$merged |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Generated templates : $($generated.Count)"
Write-Host "Curated templates   : $($curated.Count)"
Write-Host "Merged total        : $($merged.Count)"
Write-Host "Merged file written to '$OutputPath'."
### END: Merge-GenesysApiTemplates
