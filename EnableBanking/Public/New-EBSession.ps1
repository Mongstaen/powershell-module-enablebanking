function New-EBSession {
    <#
    .SYNOPSIS
        Logs in to a bank with BankID and saves the session.
    .DESCRIPTION
        Opens the bank's login in your browser. After BankID you land on a page that fails to
        load; paste its full address when asked. The session is saved under the bank's name,
        so the other commands can use -Bank.
    .EXAMPLE
        New-EBSession -Bank DNB
    #>
    [CmdletBinding()]
    param(
        # The bank's name, or a wildcard pattern that matches one bank.
        [Parameter(Mandatory)] [string] $Bank,
        [string] $Country = 'NO',
        # How long the consent lasts; the bank's maximum when shorter.
        [ValidateRange(1, 180)] [int] $Days = 180,
        [ValidateSet('personal', 'business')] [string] $PsuType = 'personal',
        # Where the bank sends you after login; Connect-EB sets the default.
        [string] $RedirectUrl = $script:RedirectUrl
    )
    $banks = @(Get-EBBank -Country $Country)
    $found = @($banks | Where-Object { $_.name -eq $Bank })
    if (-not $found.Count) { $found = @($banks | Where-Object { $_.name -like "*$Bank*" }) }
    if (-not $found.Count) { throw "No bank in $Country matches '$Bank'. See Get-EBBank." }
    if ($found.Count -gt 1) { throw "'$Bank' matches several banks: $(($found.name) -join ', '). Be more precise." }
    $aspsp = $found[0]

    $maxSeconds = (Get-EBValue $aspsp 'maximum_consent_validity') ?? 7776000
    $seconds = [math]::Min([double]$maxSeconds, $Days * 86400) - 60
    $state = [guid]::NewGuid().ToString()
    $auth = Invoke-EBApi POST '/auth' @{
        access = @{ valid_until = [DateTime]::UtcNow.AddSeconds($seconds).ToString('yyyy-MM-ddTHH:mm:ssZ') }
        aspsp = @{ name = $aspsp.name; country = $aspsp.country }
        state = $state
        redirect_url = $RedirectUrl
        psu_type = $PsuType
    }
    Write-Host "Opening the login for $($aspsp.name) in your browser. If it doesn't open, use this link:"
    Write-Host $auth.url
    Start-Process $auth.url
    Write-Host "After BankID you land on a page that fails to load. That's expected."
    $returned = Read-Host 'Paste the full address from the address bar'
    $query = [Web.HttpUtility]::ParseQueryString(([Uri]$returned.Trim()).Query)
    if ($query['error']) { throw "The bank returned an error: $($query['error']) $($query['error_description'])" }
    if ($query['state'] -ne $state) { throw 'The state in the address does not match this login. Start again.' }

    $session = Invoke-EBApi POST '/sessions' @{ code = $query['code'] }
    $sessions = Read-EBSessionFile
    $sessions[$aspsp.name] = [ordered]@{
        bank = $aspsp.name
        country = $aspsp.country
        session_id = $session.session_id
        valid_until = "$(Get-EBValue (Get-EBValue $session 'access') 'valid_until')"
        saved_at = [DateTime]::UtcNow.ToString('o')
    }
    Write-EBSessionFile $sessions
    $session
}
