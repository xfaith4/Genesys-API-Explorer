# Generated PowerShell script for Genesys Cloud API
# Endpoint: post /api/v2/analytics/conversations/details/query
# Generated: 2025-12-07 23:24:05

$token = ""
$region = "usw2.pure.cloud"
$baseUrl = "https://api.$region"
$path = "/api/v2/analytics/conversations/details/query"
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}
$url = "$baseUrl$path"

. (Join-Path $PSScriptRoot '..\tools\Import-LocalOpsInsights.ps1')

try {
    $response = Invoke-GCRequest -Method 'POST' -Uri $url -Headers $headers
    $response | ConvertTo-Json -Depth 10
} catch {
    Write-Error "Request failed: $($_.Exception.Message)"
}
