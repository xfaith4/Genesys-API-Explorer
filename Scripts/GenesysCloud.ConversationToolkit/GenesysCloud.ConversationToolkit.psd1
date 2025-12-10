### BEGIN FILE: GenesysCloud.ConversationToolkit.psd1
<#
Import-Module GenesysCloud.ConversationToolkit

# Smoke detector view → hot conversations → timeline UI
Invoke-GCSmokeDrill `
    -BaseUri 'https://api.usw2.pure.cloud' `
    -AccessToken $token `
    -Interval '2025-12-01T00:00:00.000Z/2025-12-07T23:59:59.999Z'

#>
@{
    RootModule        = 'GenesysCloud.ConversationToolkit.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'dd558d02-a6dc-4418-8590-d7b918087c4f'
    Author            = 'Ben + Genesys Cloud Conversation Toolkit'
    CompanyName       = 'Humana (internal use)'
    Copyright         = '(c) Ben. All rights reserved.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    Description = 'Genesys Cloud conversation analytics toolbox: smoke reports, hot-conversation finder, and timeline viewer.'

    # Export only the main entrypoints; everything else stays private.
    FunctionsToExport = @(
        'Get-GCConversationTimeline',
        'Export-GCConversationToExcel',
        'Get-GCQueueSmokeReport',
        'Get-GCQueueHotConversations',
        'Show-GCConversationTimelineUI',
        'Invoke-GCSmokeDrill'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags        = @('GenesysCloud','Analytics','Conversations','Humana','Troubleshooting')
            ProjectUri  = ''
            LicenseUri  = ''
            ReleaseNotes = 'Initial internal module combining conversation analytics and WPF timeline viewer.'
        }
    }
}
### END FILE: GenesysCloud.ConversationToolkit.psd1
