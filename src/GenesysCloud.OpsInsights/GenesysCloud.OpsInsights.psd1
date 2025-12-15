@{
    RootModule        = 'GenesysCloud.OpsInsights.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b5a6c3bb-8a66-4b49-9d44-6ad9b33caa11'
    Author            = 'Your Team'
    CompanyName       = 'Internal'
    Copyright         = '(c) 2025'
    Description       = 'Ops-grade Genesys Cloud Insights engine (answers → evidence → drilldown → action).'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    # Load assemblies later (SQLite plugin, etc.)
    RequiredModules   = @()

    FunctionsToExport = @(
        'Connect-GCCloud',
        'Disconnect-GCCloud',
        'Get-GCContext',
        'Invoke-GCRequest',
        'Start-GCTrace',
        'Stop-GCTrace',
        'New-GCSnapshot',
        'Save-GCSnapshot',
        'Import-GCSnapshot',
        'Invoke-GCInsightPack'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('GenesysCloud','Ops','Analytics','Architect','DataActions','Reporting')
            ProjectUri   = ''
            LicenseUri   = ''
            ReleaseNotes = 'Initial scaffold.'
        }
    }
}
