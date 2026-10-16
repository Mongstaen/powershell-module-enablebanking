function Get-EBSession {
    <#
    .SYNOPSIS
        Your saved sessions, or what Enable Banking says about one of them.
    .DESCRIPTION
        Without -Bank: the saved sessions from the file, with no call to Enable Banking.
        With -Bank: the session as Enable Banking has it now (status, accounts, access).
    .EXAMPLE
        Get-EBSession -Bank DNB | Select-Object status, access
    #>
    [CmdletBinding()]
    param([string] $Bank)
    if (-not $Bank) {
        $sessions = Read-EBSessionFile
        return $sessions.Values | ForEach-Object { [pscustomobject]$_ }
    }
    $saved = Find-EBSession $Bank
    $session = Invoke-EBApi GET "/sessions/$($saved.session_id)"
    $session | Add-Member -NotePropertyName bank -NotePropertyValue $saved.bank -Force -PassThru
}
