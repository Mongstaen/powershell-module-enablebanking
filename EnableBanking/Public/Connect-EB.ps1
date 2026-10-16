function Connect-EB {
    <#
    .SYNOPSIS
        Loads your Enable Banking application key and checks it with Enable Banking.
    .DESCRIPTION
        The key stays in memory in this PowerShell session until Disconnect-EB. Returns
        the application as Enable Banking knows it. If Enable Banking refuses the key, the
        connection you had before stays as it was.

        Each parameter you leave out is read from an environment variable, so a profile or a
        CI job can set them once: ENABLEBANKING_APP_ID, ENABLEBANKING_KEY_PATH,
        ENABLEBANKING_SESSION_FILE and ENABLEBANKING_REDIRECT_URL.
    .EXAMPLE
        Connect-EB -AppId 0c1e... -KeyPath ~/keys/enablebanking.pem
    .EXAMPLE
        Connect-EB -AppId 0c1e... -Key (Get-Secret EnableBankingKey -AsPlainText)
    .EXAMPLE
        $env:ENABLEBANKING_APP_ID = '0c1e...'
        $env:ENABLEBANKING_KEY_PATH = '~/keys/enablebanking.pem'
        Connect-EB
    #>
    [CmdletBinding(DefaultParameterSetName = 'KeyPath')]
    param(
        # The application's id, from the Enable Banking control panel.
        [string] $AppId = $env:ENABLEBANKING_APP_ID,
        # The application's private key: the .pem file made when registering it.
        [Parameter(ParameterSetName = 'KeyPath')] [string] $KeyPath = $env:ENABLEBANKING_KEY_PATH,
        # The private key itself, as PEM text. For a key kept in a secret store.
        [Parameter(Mandatory, ParameterSetName = 'Key')] [string] $Key,
        # Where New-EBSession saves sessions. Keep it out of git: with the key, it reads your accounts.
        [string] $SessionFile = ($env:ENABLEBANKING_SESSION_FILE ?? $script:DefaultSessionFile),
        # Where the bank sends you after login. It must be registered on the application.
        [string] $RedirectUrl = ($env:ENABLEBANKING_REDIRECT_URL ?? $script:DefaultRedirectUrl)
    )
    if (-not $AppId) { throw 'No application id. Pass -AppId or set ENABLEBANKING_APP_ID.' }
    if ($PSCmdlet.ParameterSetName -eq 'KeyPath') {
        if (-not $KeyPath) { throw 'No key. Pass -KeyPath or -Key, or set ENABLEBANKING_KEY_PATH.' }
        $Key = Get-Content -Raw -LiteralPath $KeyPath -ErrorAction Stop
    }

    $rsa = [Security.Cryptography.RSA]::Create()
    try { $rsa.ImportFromPem($Key) }
    catch {
        $rsa.Dispose()
        throw "The key is not a PEM private key: $($_.Exception.Message)"
    }

    $previous = $script:Connection
    $script:Connection = [pscustomobject]@{ AppId = $AppId; Rsa = $rsa; Jwt = $null; JwtExpires = [DateTimeOffset]::MinValue }
    try { $application = Invoke-EBApi GET '/application' }
    catch {
        $script:Connection = $previous
        $rsa.Dispose()
        throw
    }
    if ($previous) { $previous.Rsa.Dispose() }
    $script:SessionFile = $SessionFile
    $script:RedirectUrl = $RedirectUrl
    $application
}
