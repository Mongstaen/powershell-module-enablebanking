function Get-EBTransaction {
    <#
    .SYNOPSIS
        An account's transactions, every page, one object at a time.
    .EXAMPLE
        Get-EBAccount -Bank DNB | Get-EBTransaction -From 2026-01-01 | Export-Csv dnb.csv
    .EXAMPLE
        Get-EBTransaction -Uid <uid> -Status PDNG
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Uid,
        # yyyy-MM-dd. Without it, the bank decides how far back (often 90 days after the first hour).
        [string] $From,
        [string] $To,
        [ValidateSet('BOOK', 'PDNG')] [string] $Status
    )
    process {
        $query = @()
        if ($From) { $query += "date_from=$From" }
        if ($To) { $query += "date_to=$To" }
        if ($Status) { $query += "transaction_status=$Status" }
        $base = "/accounts/$([Uri]::EscapeDataString($Uid))/transactions"
        $key = $null
        do {
            $parts = $query + @(if ($key) { "continuation_key=$([Uri]::EscapeDataString($key))" })
            $path = if ($parts) { "${base}?$($parts -join '&')" } else { $base }
            $page = Invoke-EBApi GET $path
            $page.transactions
            $key = Get-EBValue $page 'continuation_key'
        } while ($key)
    }
}
