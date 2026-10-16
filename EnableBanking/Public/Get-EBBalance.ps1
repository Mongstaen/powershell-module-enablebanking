function Get-EBBalance {
    <#
    .SYNOPSIS
        An account's balances, one object per balance type.
    .EXAMPLE
        Get-EBAccount -Bank DNB | Get-EBBalance
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Uid)
    process { (Invoke-EBApi GET "/accounts/$([Uri]::EscapeDataString($Uid))/balances").balances }
}
