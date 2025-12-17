@{
    RootModule        = 'GenesysCloud.OpsInsights.psm1'
    ModuleVersion     = '0.3.0'
    GUID              = 'b5a6c3bb-8a66-4b49-9d44-6ad9b33caa11'
    Author            = 'Your Team'
    CompanyName       = 'Internal'
    Copyright         = '(c) 2025'
    Description       = 'Ops-grade Genesys Cloud Insights engine (answers → evidence → drilldown → action).'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    RequiredModules   = @()

    FunctionsToExport = @(
        # Connection + transport
        'Connect-GCCloud',
        'Disconnect-GCCloud',
        'Get-GCContext',
        'Invoke-GCRequest',
        'Start-GCTrace',
        'Stop-GCTrace',

        # Snapshots + packs (scaffold)
        'New-GCSnapshot',
        'Save-GCSnapshot',
        'Import-GCSnapshot',
        'Invoke-GCInsightPack',

        # Toolkit (consolidated)
        'Get-GCConversationTimeline',
        'Export-GCConversationToExcel',
        'Get-GCQueueSmokeReport',
        'Get-GCQueueHotConversations',
        'Show-GCConversationTimelineUI',
        'Invoke-GCSmokeDrill',
        
        # Reporting and aggregations
        'Get-GCDivisionReport',
        'Get-GCRoutingStatusReport'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('GenesysCloud','Ops','Analytics','Architect','DataActions','Reporting')
            ProjectUri   = ''
            LicenseUri   = ''
            ReleaseNotes = 'v0.3.0: Added division and routing status reporting with abandon rates and Not Responding tracking.'
        }
    }
}
