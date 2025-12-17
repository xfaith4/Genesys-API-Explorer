### BEGIN FILE: src\GenesysCloud.OpsInsights\Public\Get-GCConversationDetails.ps1
function Get-GCConversationDetails {
  <#
      .SYNOPSIS
        Wrapper for /api/v2/analytics/conversations/details
      .NOTES
        PR2: Keep it dead simple + fixture-friendly.
        Auth is expected to be handled elsewhere; transport will use $global:AccessToken if present.
    #>
  [CmdletBinding()]
  param(
    # ISO interval string: "start/end" (UTC recommended)
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Interval,

    [Parameter()]
    [int]$PageSize = 100,

    [Parameter()]
    [string]$Cursor,

    # Optional body filters you may add later; PR2 keeps it flexible
    [Parameter()]
    [hashtable]$Filter
  )

  $path = "/api/v2/analytics/conversations/details?pageSize=$($PageSize)&interval=$([uri]::EscapeDataString($Interval))"
  if ($Cursor) {
    $path += "&cursor=$([uri]::EscapeDataString($Cursor))"
  }

  $body = @{}
  if ($Filter) { $body.filter = $Filter }

  $resp = Invoke-GCRequest -Method POST -Path $path -Body $body

  # Normalize common response shape for callers
  [pscustomobject]@{
    Conversations = @($resp.conversations)
    Cursor        = $resp.cursor
    Raw           = $resp
  }
}
### END FILE
