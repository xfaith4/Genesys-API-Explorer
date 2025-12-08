### BEGIN FILE: Generate-GenesysCloudTemplates.ps1
[CmdletBinding()]
param(
    # The JSON you just extracted from the zip
    [Parameter(Mandatory=$true)]
    [string]$EndpointJsonPath,

    # Your existing curated templates (the JSON you pasted in the first message)
    [Parameter(Mandatory=$false)]
    [string]$ExistingTemplatePath = ".\GenesysApiTemplates.json",

    # Where to write the combined output
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\GenesysApiTemplates.generated.json",

    # Limit which paths we convert into templates
    [Parameter(Mandatory=$false)]
    [string[]]$IncludePathPrefix = @(
        "/api/v2/conversations",
        "/api/v2/analytics",
        "/api/v2/quality"
    ),

    # Optional: further limit by OpenAPI tags (e.g. "Conversations")
    [Parameter(Mandatory=$false)]
    [string[]]$IncludeTag = @()
)

# ---------------------------
# Safety checks and loading
# ---------------------------

if (-not (Test-Path -LiteralPath $EndpointJsonPath)) {
    throw "Endpoint JSON file not found at '$($EndpointJsonPath)'."
}

# Load and parse the endpoints JSON (this is the file from your zip)
$endpointJson = Get-Content -LiteralPath $EndpointJsonPath -Raw
$endpointRoot = $endpointJson | ConvertFrom-Json

# The actual OpenAPI spec lives under this key in that file
$spec = $endpointRoot.'openapi-cache-https---api-mypurecloud-com-api-v2-docs-swagger'
if (-not $spec) {
    throw "Could not find OpenAPI spec under 'openapi-cache-https---api-mypurecloud-com-api-v2-docs-swagger' in '$($EndpointJsonPath)'."
}

if (-not $spec.paths) {
    throw "OpenAPI spec in '$($EndpointJsonPath)' does not expose a 'paths' property."
}

# Load existing templates so we can append auto-generated ones
$existingTemplates = @()
if ($ExistingTemplatePath -and (Test-Path -LiteralPath $ExistingTemplatePath)) {
    $existingJson      = Get-Content -LiteralPath $ExistingTemplatePath -Raw
    $existingTemplates = $existingJson | ConvertFrom-Json
}

# Use a List for efficient appends
$allTemplates = [System.Collections.Generic.List[object]]::new()
if ($existingTemplates) {
    # Preserve your hand-crafted stuff up front
    $allTemplates.AddRange([object[]]$existingTemplates)
}

$now = Get-Date

# ---------------------------
# Helper: Path prefix filter
# ---------------------------
function Test-IncludePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string[]]$Prefixes
    )

    # If no prefixes specified, include everything
    if (-not $Prefixes -or $Prefixes.Count -eq 0) {
        return $true
    }

    foreach ($p in $Prefixes) {
        if ($Path.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

# ---------------------------
# Main: Iterate all paths/methods
# ---------------------------

$paths = $spec.paths
$pathCount = 0
$templateCountBefore = $allTemplates.Count

foreach ($pathProp in $paths.PSObject.Properties) {
    $path = $pathProp.Name

    # Limit to your functional areas
    if (-not (Test-IncludePath -Path $path -Prefixes $IncludePathPrefix)) {
        continue
    }

    $pathItem = $pathProp.Value
    $pathCount++

    # Each HTTP method under the path
    foreach ($methodProp in $pathItem.PSObject.Properties) {
        $method = $methodProp.Name.ToUpperInvariant()

        # Only process real HTTP verbs
        if ($method -notin @('GET','POST','PUT','DELETE','PATCH')) {
            continue
        }

        $op = $methodProp.Value

        # Optional tag filter (e.g. only "Conversations")
        if ($IncludeTag -and $IncludeTag.Count -gt 0) {
            $tags = @($op.tags)
            if (-not $tags -or -not ($tags | Where-Object { $_ -in $IncludeTag })) {
                continue
            }
        }

        # Build Parameters: path params + body (if any)
        $paramObj  = [ordered]@{}
        $allParams = @()

        # Path-level parameters
        if ($pathItem.parameters) {
            $allParams += $pathItem.parameters
        }

        # Operation-level parameters
        if ($op.parameters) {
            $allParams += $op.parameters
        }

        # Path parameters: /{conversationId}/... → "conversationId": "conversationId-goes-here"
        foreach ($p in $allParams | Where-Object { $_.in -eq 'path' }) {
            $placeholder = ("{0}-goes-here" -f $p.name)
            $paramObj[$p.name] = $placeholder
        }

        # Try to grab an example or default request body
        $bodyJson = $null

        if ($op.requestBody -and $op.requestBody.content) {
            # OpenAPI v3 style; might not apply if this is older swagger, but keep it anyway
            $content = $op.requestBody.content.'application/json'
            if ($content) {
                if ($content.example) {
                    $bodyJson = $content.example | ConvertTo-Json -Depth 10
                }
                elseif ($content.examples) {
                    $firstExample = $content.examples.PSObject.Properties.Value | Select-Object -First 1
                    if ($firstExample -and $firstExample.value) {
                        $bodyJson = $firstExample.value | ConvertTo-Json -Depth 10
                    }
                }
                elseif ($content.schema -and $content.schema.default) {
                    $bodyJson = $content.schema.default | ConvertTo-Json -Depth 10
                }
            }
        }
        elseif ($op.parameters) {
            # Swagger 2.0 style body param (in: "body")
            $bodyParam = $op.parameters | Where-Object { $_.in -eq 'body' } | Select-Object -First 1
            if ($bodyParam) {
                if ($bodyParam.example) {
                    $bodyJson = $bodyParam.example | ConvertTo-Json -Depth 10
                }
                elseif ($bodyParam.schema -and $bodyParam.schema.default) {
                    $bodyJson = $bodyParam.schema.default | ConvertTo-Json -Depth 10
                }
            }
        }

        # For write verbs, attach the body if we could infer one
        if ($bodyJson -and $method -in @('POST','PUT','PATCH')) {
            # Store as raw JSON string so your GUI can show/edit it
            $paramObj['body'] = $bodyJson
        }

        # Group: prefer OpenAPI tag; fallback to path segment after /api/v2/
        $group = $null
        if ($op.tags -and $op.tags.Count -gt 0) {
            $group = $op.tags[0]
        }

        if (-not $group) {
            $segments = $path.Trim('/') -split '/'
            # Example: /api/v2/conversations/calls → ["api","v2","conversations","calls"]
            if ($segments.Length -ge 3) {
                $group = $segments[2]
            }
            else {
                $group = $segments[-1]
            }
        }

        # Name: use operationId if present, otherwise METHOD + Path
        $name = if ($op.operationId) {
            $op.operationId
        }
        else {
            "{0} {1}" -f $method, $path
        }

        # Template object matching your existing structure
        $template = [ordered]@{
            Name       = $name
            Method     = $method
            Path       = $path
            Group      = $group
            Parameters = $paramObj
            Created    = $now.ToString('yyyy-MM-dd HH:mm:ss')
        }

        $allTemplates.Add($template)
    }
}

$templateCountAfter = $allTemplates.Count
$templateDelta      = $templateCountAfter - $templateCountBefore

Write-Host "Paths inspected      : $($pathCount)"
Write-Host "Existing templates   : $($templateCountBefore)"
Write-Host "New templates added  : $($templateDelta)"
Write-Host "Total templates now  : $($templateCountAfter)"

# ---------------------------
# Write out combined result
# ---------------------------

$allTemplates |
    ConvertTo-Json -Depth 10 |
    Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Host "Templates written to '$($OutputPath)'."
### END FILE: Generate-GenesysCloudTemplates.ps1
