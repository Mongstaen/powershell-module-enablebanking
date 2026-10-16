@{
    RootModule = 'EnableBanking.psm1'
    ModuleVersion = '0.1.0'
    GUID = '7c3f2b8e-5d41-4a7e-9a62-1e0b6f4d8c25'
    Author = 'Thomas'
    Description = 'Enable Banking from PowerShell: log in to a bank with BankID and see exactly what it sends.'
    PowerShellVersion = '7.2'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @('Connect-EB', 'Disconnect-EB', 'Get-EBBank', 'New-EBSession', 'Get-EBSession',
        'Get-EBAccount', 'Get-EBAccountDetails', 'Get-EBBalance', 'Get-EBTransaction', 'Remove-EBSession')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
