function Get-EBBank {
    <#
    .SYNOPSIS
        The banks Enable Banking can reach in a country.
    .EXAMPLE
        Get-EBBank -Name '*sparebank*' | Select-Object name, maximum_consent_validity
    #>
    [CmdletBinding()]
    param(
        # A wildcard pattern for the bank's name.
        [string] $Name = '*',
        [string] $Country = 'NO'
    )
    (Invoke-EBApi GET "/aspsps?country=$([Uri]::EscapeDataString($Country))").aspsps |
        Where-Object { $_.name -like $Name }
}
