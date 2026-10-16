#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5' }
# Run: Invoke-Pester tools/EnableBanking/tests
# No test talks to Enable Banking: Invoke-WebRequest is mocked inside the module, and Reply
# builds what it would have returned.

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'EnableBanking.psd1') -Force

    $script:dir = Join-Path ([IO.Path]::GetTempPath()) "eb-tests-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $script:dir | Out-Null
    $script:rsa = [Security.Cryptography.RSA]::Create(2048)
    $script:keyPath = Join-Path $script:dir 'key.pem'
    Set-Content -LiteralPath $script:keyPath -Value $script:rsa.ExportRSAPrivateKeyPem()
    $script:sessionFile = Join-Path $script:dir 'sessions.json'

    function Reply([int] $Status, $Object = $null) {
        [pscustomobject]@{ StatusCode = $Status; Content = if ($null -eq $Object) { '' } else { $Object | ConvertTo-Json -Depth 8 } }
    }

    function Connect-Test {
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/application' } {
            Reply 200 @{ name = 'Pengesluket test'; environment = 'PRODUCTION' }
        }
        Connect-EB -AppId 'app-123' -KeyPath $script:keyPath -SessionFile $script:sessionFile
    }

    function Save-TestSession([string] $Bank = 'DNB', [string] $Id = 'sess-1') {
        @{ $Bank = @{ session_id = $Id; bank = $Bank; country = 'NO'; valid_until = '2027-04-01T00:00:00Z'
                saved_at = '2026-10-15T12:00:00Z' } } |
            ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:sessionFile
    }

    function Mock-Banks {
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/aspsps?country=NO' } {
            Reply 200 @{ aspsps = @(
                    @{ name = 'DNB'; country = 'NO'; maximum_consent_validity = 15552000 },
                    @{ name = 'SpareBank 1 Sør-Norge'; country = 'NO' }) }
        }
    }
}

AfterAll {
    Disconnect-EB
    Remove-Item -Recurse -Force $script:dir
}

Describe 'Connect-EB' {
    It 'returns the application and signs a JWT Enable Banking accepts' {
        $app = Connect-Test
        $app.name | Should -Be 'Pengesluket test'

        $jwt = InModuleScope EnableBanking { Get-EBToken }
        $header, $payload, $signature = $jwt.Split('.')
        $decode = {
            param($part)
            $p = $part.Replace('-', '+').Replace('_', '/')
            $p += '=' * ((4 - $p.Length % 4) % 4)
            [Convert]::FromBase64String($p)
        }
        $head = [Text.Encoding]::UTF8.GetString((& $decode $header)) | ConvertFrom-Json
        $body = [Text.Encoding]::UTF8.GetString((& $decode $payload)) | ConvertFrom-Json
        $head.alg | Should -Be 'RS256'
        $head.kid | Should -Be 'app-123'
        $body.iss | Should -Be 'enablebanking.com'
        $body.aud | Should -Be 'api.enablebanking.com'
        ($body.exp - $body.iat) | Should -Be 3600
        $script:rsa.VerifyData([Text.Encoding]::UTF8.GetBytes("$header.$payload"), (& $decode $signature),
            [Security.Cryptography.HashAlgorithmName]::SHA256,
            [Security.Cryptography.RSASignaturePadding]::Pkcs1) | Should -BeTrue
    }

    It 'refuses commands before connecting' {
        Disconnect-EB
        { Get-EBBank } | Should -Throw '*Connect-EB*'
    }

    It 'takes the key as PEM text' {
        Mock Invoke-WebRequest -ModuleName EnableBanking { Reply 200 @{ name = 'From text' } }
        $app = Connect-EB -AppId 'app-123' -Key (Get-Content -Raw -LiteralPath $script:keyPath) -SessionFile $script:sessionFile
        $app.name | Should -Be 'From text'
    }

    It 'reads what is left out from environment variables' {
        Mock Invoke-WebRequest -ModuleName EnableBanking { Reply 200 @{ name = 'From env' } }
        $env:ENABLEBANKING_APP_ID = 'app-env'
        $env:ENABLEBANKING_KEY_PATH = $script:keyPath
        $env:ENABLEBANKING_SESSION_FILE = $script:sessionFile
        $env:ENABLEBANKING_REDIRECT_URL = 'https://example.test/back'
        try {
            (Connect-EB).name | Should -Be 'From env'
            InModuleScope EnableBanking {
                $script:Connection.AppId | Should -Be 'app-env'
                $script:RedirectUrl | Should -Be 'https://example.test/back'
            }
        }
        finally {
            Remove-Item Env:ENABLEBANKING_APP_ID, Env:ENABLEBANKING_KEY_PATH, Env:ENABLEBANKING_SESSION_FILE,
                Env:ENABLEBANKING_REDIRECT_URL
        }
    }

    It 'says what is missing without an application id' {
        { Connect-EB -KeyPath $script:keyPath } | Should -Throw '*ENABLEBANKING_APP_ID*'
    }

    It 'refuses text that is not a PEM key' {
        { Connect-EB -AppId 'app-123' -Key 'not a key' } | Should -Throw '*not a PEM private key*'
    }

    It 'keeps the previous connection when Enable Banking refuses the key' {
        Connect-Test
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/application' } {
            Reply 401 @{ error = 'UNAUTHORIZED'; message = 'Bad key' }
        }
        { Connect-EB -AppId 'app-other' -KeyPath $script:keyPath } | Should -Throw '*401*'
        InModuleScope EnableBanking { $script:Connection.AppId | Should -Be 'app-123' }
    }
}

Describe 'Errors from Enable Banking' {
    BeforeEach { Connect-Test }

    It 'stops with the status and Enable Banking''s own code and message' {
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/aspsps*' } {
            Reply 422 @{ error = 'WRONG_REQUEST_PARAMETERS'; message = 'country is not valid' }
        }
        { Get-EBBank -Country XX } | Should -Throw '*422*WRONG_REQUEST_PARAMETERS*country is not valid*'
    }

    It 'reports an answer that only has a detail' {
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/aspsps*' } {
            Reply 404 @{ detail = 'Not Found' }
        }
        { Get-EBBank } | Should -Throw '*404*Not Found*'
    }

    It 'reports an empty error answer' {
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/aspsps*' } { Reply 503 }
        { Get-EBBank } | Should -Throw '*503*GET /aspsps*'
    }
}

Describe 'Get-EBBank' {
    BeforeEach { Connect-Test; Mock-Banks }

    It 'filters the bank list by a wildcard pattern' {
        (Get-EBBank -Name 'spare*').name | Should -Be 'SpareBank 1 Sør-Norge'
        @(Get-EBBank) | Should -HaveCount 2
    }
}

Describe 'Get-EBTransaction' {
    BeforeEach { Connect-Test }

    It 'follows continuation_key through every page' {
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/transactions*' -and $Uri -notlike '*continuation_key*' } {
            Reply 200 @{ transactions = @(@{ n = 1 }, @{ n = 2 }); continuation_key = 'k/2' }
        }
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*continuation_key=k%2F2*' } {
            Reply 200 @{ transactions = @(@{ n = 3 }); continuation_key = $null }
        }
        $all = @(Get-EBTransaction -Uid 'acc-1' -From '2026-01-01' -To '2026-03-31' -Status BOOK)
        $all.n | Should -Be @(1, 2, 3)
        Should -Invoke Invoke-WebRequest -ModuleName EnableBanking -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/accounts/acc-1/transactions?date_from=2026-01-01&date_to=2026-03-31&transaction_status=BOOK'
        }
    }

    It 'takes the account uid from the pipeline' {
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/transactions*' } {
            Reply 200 @{ transactions = @(@{ n = 1 }) }
        }
        @([pscustomobject]@{ uid = 'a' }, [pscustomobject]@{ uid = 'b' }) | Get-EBTransaction | Should -HaveCount 2
        Should -Invoke Invoke-WebRequest -ModuleName EnableBanking -Times 1 -Exactly -ParameterFilter { $Uri -like '*/accounts/b/transactions*' }
    }
}

Describe 'Account details and balances' {
    BeforeEach { Connect-Test }

    It 'returns the bank''s details and balances for the uid' {
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/accounts/u1/details' } {
            Reply 200 @{ name = 'Brukskonto'; product = 'Lønnskonto' }
        }
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/accounts/u1/balances' } {
            Reply 200 @{ balances = @(@{ balance_type = 'CLBD'; balance_amount = @{ amount = '100.00'; currency = 'NOK' } }) }
        }
        (Get-EBAccountDetails -Uid u1).product | Should -Be 'Lønnskonto'
        (Get-EBBalance -Uid u1).balance_type | Should -Be 'CLBD'
    }
}

Describe 'Saved sessions' {
    BeforeEach {
        Connect-Test
        Remove-Item -LiteralPath $script:sessionFile -ErrorAction SilentlyContinue
    }

    It 'lists nothing when no session is saved' {
        @(Get-EBSession) | Should -HaveCount 0
    }

    It 'lists saved sessions without calling Enable Banking' {
        Save-TestSession 'DNB' 'sess-1'
        Mock Invoke-WebRequest -ModuleName EnableBanking { throw 'no API call expected' }
        $saved = @(Get-EBSession)
        $saved.bank | Should -Be 'DNB'
        $saved.session_id | Should -Be 'sess-1'
    }

    It 'asks Enable Banking about the saved session for -Bank' {
        Save-TestSession 'DNB' 'sess-1'
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/sessions/sess-1' } {
            Reply 200 @{ status = 'AUTHORIZED'; accounts = @('u1') }
        }
        (Get-EBSession -Bank dnb).status | Should -Be 'AUTHORIZED'
    }

    It 'says which banks have a session when -Bank has none' {
        Save-TestSession 'DNB' 'sess-1'
        { Get-EBSession -Bank 'SAS*' } | Should -Throw '*No saved session*DNB*'
    }

    It 'saves a new session from the bank''s return address' {
        Mock-Banks
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/auth' } {
            $script:sentAuth = $Body | ConvertFrom-Json
            Reply 200 @{ url = 'https://bank.example/login' }
        }
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/sessions' -and $Method -eq 'POST' } {
            Reply 200 @{ session_id = 'sess-new'; access = @{ valid_until = '2027-04-10T10:00:00Z' }
                accounts = @(@{ uid = 'u1'; identification_hash = 'h1' }) }
        }
        Mock Start-Process -ModuleName EnableBanking {}
        Mock Read-Host -ModuleName EnableBanking { "https://localhost:8443/callback?code=C1&state=$($script:sentAuth.state)" }

        $session = New-EBSession -Bank DNB
        $session.session_id | Should -Be 'sess-new'
        $script:sentAuth.aspsp.name | Should -Be 'DNB'
        $script:sentAuth.psu_type | Should -Be 'personal'
        (Get-EBSession).session_id | Should -Be 'sess-new'
    }

    It 'refuses a return address with another state, and saves nothing' {
        Mock-Banks
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/auth' } {
            Reply 200 @{ url = 'https://bank.example/login' }
        }
        Mock Start-Process -ModuleName EnableBanking {}
        Mock Read-Host -ModuleName EnableBanking { 'https://localhost:8443/callback?code=C1&state=someone-else' }
        { New-EBSession -Bank DNB } | Should -Throw '*state*'
        Test-Path -LiteralPath $script:sessionFile | Should -BeFalse
    }

    It 'asks which bank when the name matches several' {
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/aspsps?country=NO' } {
            Reply 200 @{ aspsps = @(@{ name = 'SpareBank 1 Nord'; country = 'NO' }, @{ name = 'SpareBank 1 Sør-Norge'; country = 'NO' }) }
        }
        { New-EBSession -Bank 'SpareBank 1' } | Should -Throw '*SpareBank 1 Nord*SpareBank 1 Sør-Norge*'
    }

    It 'gives each account in the session with its bank' {
        Save-TestSession 'DNB' 'sess-1'
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Uri -like '*/sessions/sess-1' } {
            Reply 200 @{ status = 'AUTHORIZED'; accounts = @('u1', 'u2')
                accounts_data = @(@{ uid = 'u1'; identification_hash = 'h1' }, @{ uid = 'u2'; identification_hash = 'h2' }) }
        }
        $accounts = @(Get-EBAccount -Bank DNB)
        $accounts.uid | Should -Be @('u1', 'u2')
        $accounts.identification_hash | Should -Be @('h1', 'h2')
        $accounts.bank | Should -Be @('DNB', 'DNB')
    }

    It 'removes a session only when confirmed' {
        Save-TestSession 'DNB' 'sess-1'
        Mock Invoke-WebRequest -ModuleName EnableBanking -ParameterFilter { $Method -eq 'DELETE' } { Reply 200 }
        Remove-EBSession -Bank DNB -WhatIf
        Should -Invoke Invoke-WebRequest -ModuleName EnableBanking -Times 0 -Exactly -ParameterFilter { $Method -eq 'DELETE' }
        Remove-EBSession -Bank DNB -Confirm:$false
        Should -Invoke Invoke-WebRequest -ModuleName EnableBanking -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'DELETE' -and $Uri -like '*/sessions/sess-1' }
        @(Get-EBSession) | Should -HaveCount 0
    }
}
