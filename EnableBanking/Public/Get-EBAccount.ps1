function Get-EBAccount {
    <#
    .SYNOPSIS
        The accounts in a bank's saved session: uid and identification_hash.
    .DESCRIPTION
        Asks Enable Banking, not the bank, so it does not count against the bank's daily
        limit. Pipe the result to Get-EBAccountDetails, Get-EBBalance or Get-EBTransaction.
    .EXAMPLE
        Get-EBAccount -Bank DNB | Get-EBAccountDetails
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Bank)
    $session = Get-EBSession -Bank $Bank
    $data = @(Get-EBValue $session 'accounts_data')
    foreach ($uid in @($session.accounts)) {
        [pscustomobject]@{
            uid = $uid
            identification_hash = @($data | Where-Object uid -eq $uid)[0]?.identification_hash
            bank = $session.bank
        }
    }
}
