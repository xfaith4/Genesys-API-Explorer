### BEGIN: Add-GenericAnalyticsBodies
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$TemplatePath,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\GenesysApiTemplates.analyticsBodies.json"
)

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template file not found at '$TemplatePath'."
}

$json     = Get-Content -LiteralPath $TemplatePath -Raw
$templates = $json | ConvertFrom-Json

# Generic analytics aggregates payload you can tweak as needed
$genericAggregatesBody = @"
{
  "interval": "2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z",
  "granularity": "P1D",
  "groupBy": [],
  "metrics": [],
  "filter": {
    "type": "and",
    "predicates": []
  },
  "order": "asc"
}
"@

foreach ($tpl in $templates) {

    # Ensure Parameters is at least an object
    if (-not $tpl.Parameters) {
        $tpl.Parameters = [ordered]@{}
    }

    $path   = $tpl.Path
    $method = $tpl.Method

    # Add a generic body for analytics *aggregates/query* posts that don't have one yet
    if ($method -eq 'POST' -and
        $path -like '/api/v2/analytics/*/aggregates/query' -and
        -not $tpl.Parameters.ContainsKey('body')) {

        # Assign the generic JSON text as a string body
        $tpl.Parameters['body'] = $genericAggregatesBody
    }
}

$templates |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Patched analytics aggregates templates written to '$OutputPath'."
### END: Add-GenericAnalyticsBodies
