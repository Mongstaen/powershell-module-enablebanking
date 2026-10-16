# Enable Banking from PowerShell: see exactly what the banks send.
#
# Every command returns Enable Banking's own objects, untouched, so they can be
# piped, filtered and exported. Nothing is hidden: the output holds real names,
# account numbers and amounts.
#
# Calls to an account (details, balances, transactions) go to the bank. Without you
# present, banks allow only about 4 of them per account per day (PSD2).

Set-StrictMode -Version Latest

$script:Api = 'https://api.enablebanking.com'
$script:DefaultSessionFile = Join-Path $HOME '.enablebanking/sessions.json'
$script:DefaultRedirectUrl = 'https://localhost:8443/callback'

# Set by Connect-EB: the application id, its key and the JWT signed with it.
$script:Connection = $null
$script:SessionFile = $env:ENABLEBANKING_SESSION_FILE ?? $script:DefaultSessionFile
$script:RedirectUrl = $env:ENABLEBANKING_REDIRECT_URL ?? $script:DefaultRedirectUrl

# One function per file: Private/ holds the helpers, Public/ the commands, each named
# after the function it defines.
foreach ($folder in 'Private', 'Public') {
    foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot $folder) -Filter *.ps1) {
        . $file.FullName
    }
}

Export-ModuleMember -Function (Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter *.ps1).BaseName
