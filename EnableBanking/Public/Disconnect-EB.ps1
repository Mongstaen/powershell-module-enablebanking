function Disconnect-EB {
    <#
    .SYNOPSIS
        Forgets the application key. Saved sessions stay in their file.
    #>
    [CmdletBinding()]
    param()
    if ($script:Connection) { $script:Connection.Rsa.Dispose() }
    $script:Connection = $null
}
