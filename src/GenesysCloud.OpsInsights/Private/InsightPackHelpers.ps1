### BEGIN FILE: Private\InsightPackHelpers.ps1
function Get-GCInsightPackParameters {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Pack,
        [Parameter()]
        [hashtable]$Overrides
    )

    $result = [ordered]@{}
    if ($Pack.parameters) {
        foreach ($prop in $Pack.parameters.PSObject.Properties) {
            $result[$prop.Name] = $prop.Value
        }
    }

    if ($Overrides) {
        foreach ($key in $Overrides.Keys) {
            $result[$key] = $Overrides[$key]
        }
    }

    return $result
}

function Resolve-GCInsightTemplateString {
    param(
        [Parameter(Mandatory)]
        [string]$Template,
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )

    if (-not $Template) { return $Template }

    $result = $Template
    foreach ($paramName in $Parameters.Keys) {
        $token = "{{{0}}}" -f $paramName
        $value = if ($Parameters[$paramName] -eq $null) { '' } else { [string]$Parameters[$paramName] }
        $result = $result -replace [regex]::Escape($token), $value
    }

    return $result
}

function Resolve-GCInsightPackQueryString {
    param(
        [Parameter()]
        $QueryTemplate,
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )

    if (-not $QueryTemplate) { return '' }

    $parts = @()
    foreach ($key in $QueryTemplate.Keys) {
        $valueTemplate = $QueryTemplate[$key]
        $value = if ($valueTemplate -is [string]) {
            Resolve-GCInsightTemplateString -Template $valueTemplate -Parameters $Parameters
        } else {
            $valueTemplate
        }
        if ($null -eq $value) { continue }
        $parts += "{0}={1}" -f $key, [System.Uri]::EscapeDataString([string]$value)
    }

    if ($parts.Count -eq 0) { return '' }
    return ('?' + ($parts -join '&'))
}

function Resolve-GCInsightPackHeaders {
    param(
        [Parameter()]
        $HeadersTemplate,
        [Parameter(Mandatory)]
        [hashtable]$Parameters
    )

    if (-not $HeadersTemplate) { return @{} }

    $headers = @{}
    foreach ($key in $HeadersTemplate.Keys) {
        $valueTemplate = $HeadersTemplate[$key]
        $value = if ($valueTemplate -is [string]) {
            Resolve-GCInsightTemplateString -Template $valueTemplate -Parameters $Parameters
        } else {
            $valueTemplate
        }
        if ($null -ne $value) {
            $headers[$key] = $value
        }
    }

    return $headers
}

function New-GCInsightStepLog {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$StepDefinition
    )

    return [ordered]@{
        Id           = $StepDefinition.id
        Type         = $StepDefinition.type
        Description  = if ($StepDefinition.description) { $StepDefinition.description } else { $null }
        StartedUtc   = (Get-Date).ToUniversalTime()
        EndedUtc     = $null
        DurationMs   = 0
        Status       = 'Pending'
        ErrorMessage = $null
        ResultSummary= $null
    }
}

