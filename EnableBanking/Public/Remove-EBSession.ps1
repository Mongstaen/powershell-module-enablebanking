function Remove-EBSession {
    <#
    .SYNOPSIS
        Ends a bank's session at Enable Banking and removes it from the file.
    .EXAMPLE
        Remove-EBSession -Bank DNB
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([Parameter(Mandatory)] [string] $Bank)
    $saved = Find-EBSession $Bank
    if (-not $PSCmdlet.ShouldProcess($saved.bank, 'End the Enable Banking session')) { return }
    Invoke-EBApi DELETE "/sessions/$($saved.session_id)" | Out-Null
    $sessions = Read-EBSessionFile
    $sessions.Remove($saved.bank)
    Write-EBSessionFile $sessions
}
