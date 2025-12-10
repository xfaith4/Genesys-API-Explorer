<#
.SYNOPSIS
Example script demonstrating integration of GenesysCloud.ConversationToolkit with the main API Explorer.

.DESCRIPTION
This script shows how to:
1. Use conversation IDs from your API Explorer queries
2. Feed those IDs into the ConversationToolkit for deep analysis
3. Export professional Excel reports with MediaEndpointStats and WebRTC error tracking
4. Identify routing issues and quality problems

.EXAMPLE
.\Analyze-ConversationWithToolkit.ps1 -BaseUri 'https://api.usw2.pure.cloud' -AccessToken $token

.NOTES
Requires:
- GenesysCloud.ConversationToolkit module
- ImportExcel module (Install-Module ImportExcel -Scope CurrentUser)
- Valid Genesys Cloud OAuth token with appropriate permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUri,

    [Parameter(Mandatory = $true)]
    [string]$AccessToken,

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = ".\ConversationReports"
)

# Ensure output directory exists
if (-not (Test-Path $OutputDirectory)) {
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    Write-Host "Created output directory: $OutputDirectory" -ForegroundColor Cyan
}

# Import the ConversationToolkit module
$modulePath = Join-Path $PSScriptRoot "..\Scripts\GenesysCloud.ConversationToolkit\GenesysCloud.ConversationToolkit.psd1"
if (-not (Test-Path $modulePath)) {
    Write-Error "ConversationToolkit module not found at: $modulePath"
    exit 1
}

Write-Host "Importing ConversationToolkit module..." -ForegroundColor Cyan
Import-Module $modulePath -Force
Write-Host "✓ Module imported successfully`n" -ForegroundColor Green

# Main execution
Write-Host "========================================" -ForegroundColor Green
Write-Host "GenesysCloud.ConversationToolkit Examples" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "This script demonstrates integration of the ConversationToolkit." -ForegroundColor Cyan
Write-Host "See docs/CONVERSATION_TOOLKIT.md for complete documentation and workflow examples.`n" -ForegroundColor Cyan

# Example: Analyze a specific conversation (modify with your conversation ID)
# $conversationId = 'your-conversation-id-here'
# $timeline = Get-GCConversationTimeline -BaseUri $BaseUri -AccessToken $AccessToken -ConversationId $conversationId
# Export-GCConversationToExcel -ConversationData $timeline -OutputPath (Join-Path $OutputDirectory "Report.xlsx") -IncludeRawData

Write-Host "Module ready! See docs/CONVERSATION_TOOLKIT.md for detailed examples." -ForegroundColor Green
