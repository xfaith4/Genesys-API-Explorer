@{
    RootModule        = 'OpsConsole.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '13b04534-147a-4961-813c-1d81bfc21326'
    Author            = 'Genesys API Explorer'
    CompanyName       = 'Genesys'
    Copyright         = '(c) Genesys. All rights reserved.'
    Description       = 'UI shell module for the Ops Console entrypoint.'
    PowerShellVersion = '5.1'
    FunctionsToExport = 'Start-GCOpsConsole'
    PrivateData       = @{
        PSData = @{
            Tags        = 'GenesysCloud', 'OpsConsole'
            ReleaseNotes = 'PR3: GUI moved into apps/OpsConsole with explicit Start-GCOpsConsole entrypoint.'
        }
    }
}
