function Get-EBAccountDetails {
    <#
    .SYNOPSIS
        An account as the bank describes it: name, account number, product, type.
    .EXAMPLE
        Get-EBAccount -Bank DNB | Get-EBAccountDetails | Select-Object name, product, account_id
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Uid)
    process { Invoke-EBApi GET "/accounts/$([Uri]::EscapeDataString($Uid))/details" }
}
