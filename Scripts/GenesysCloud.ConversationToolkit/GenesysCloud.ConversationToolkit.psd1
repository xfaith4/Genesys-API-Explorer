@{
    RootModule        = 'GenesysCloud.ConversationToolkit.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '9a3a6c7d-2b56-4c69-b4f8-4a6bb7a7e0f5'
    Author            = 'Internal'
    CompanyName       = 'Internal'
    Copyright         = '(c) 2025'
    Description       = 'Compatibility shim for GenesysCloud.OpsInsights (toolkit moved).'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    FunctionsToExport = @(
        'Invoke-GCRequest',
        'Get-GCConversationTimeline',
        'Export-GCConversationToExcel',
        'Get-GCQueueSmokeReport',
        'Get-GCQueueHotConversations',
        'Show-GCConversationTimelineUI',
        'Invoke-GCSmokeDrill'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('GenesysCloud','Compatibility')
            ReleaseNotes = 'Shim module; functionality moved to GenesysCloud.OpsInsights.'
        }
    }
}
