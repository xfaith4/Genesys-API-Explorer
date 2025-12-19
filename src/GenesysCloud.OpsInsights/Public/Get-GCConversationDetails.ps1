### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Get-GCConversationDetails.ps1
function Get-GCConversationDetails {
  <#
      .SYNOPSIS
        Wrapper for /api/v2/analytics/conversations/details
      .NOTES
        PR2: Keep it dead simple + fixture-friendly.
        Auth is expected to be handled elsewhere; transport will use $global:AccessToken if present.
    #>
  [CmdletBinding(DefaultParameterSetName = 'Interval')]
  param(
    # ISO interval string: "start/end" (UTC recommended)
    [Parameter(Mandatory, ParameterSetName = 'Interval')]
    [ValidateNotNullOrEmpty()]
    [string]$Interval,

    [Parameter(ParameterSetName = 'Interval')]
    [int]$PageSize = 100,

    [Parameter(ParameterSetName = 'Interval')]
    [string]$Cursor,

    # Optional body filters you may add later; PR2 keeps it flexible
    [Parameter(ParameterSetName = 'Interval')]
    [hashtable]$Filter,

    # Direct query payload (POST /query) for offline fixtures and advanced filters
    [Parameter(Mandatory, ParameterSetName = 'Query')]
    [hashtable]$Query
  )

  if ($PSCmdlet.ParameterSetName -eq 'Query') {
    $resp = Invoke-GCRequest -Method POST -Path "/api/v2/analytics/conversations/details/query" -Body $Query
  }
  else {
    $path = "/api/v2/analytics/conversations/details?pageSize=$($PageSize)&interval=$([uri]::EscapeDataString($Interval))"
    if ($Cursor) {
      $path += "&cursor=$([uri]::EscapeDataString($Cursor))"
    }

    $body = @{}
    if ($Filter) { $body.filter = $Filter }

    $resp = Invoke-GCRequest -Method POST -Path $path -Body $body
  }

  # Normalize common response shape for callers
  [pscustomobject]@{
    Conversations = @($resp.conversations)
    Cursor        = $resp.cursor
    Raw           = $resp
  }
}
### END FILE
