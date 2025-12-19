@{
    RootModule        = 'GenesysCloud.OpsInsights.Core.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b4e0f0c7-3cf4-4b34-b0f2-2d6d7d3f1c6c'
    Author            = 'OpsInsights Team'
    CompanyName       = 'Internal'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    Description       = 'Core helpers for OpsInsights (transport-agnostic exports).'

    FunctionsToExport = @(
        'Export-GCInsightPackHtml'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('GenesysCloud','OpsInsights','Core')
            ProjectUri = ''
        }
    }
}
