# A JWT signed with the application's key, renewed when it has less than five minutes left.
function Get-EBToken {
    $connection = $script:Connection
    if (-not $connection) { throw 'Not connected. Run Connect-EB first.' }
    $now = [DateTimeOffset]::UtcNow
    if ($connection.Jwt -and $connection.JwtExpires -gt $now.AddMinutes(5)) { return $connection.Jwt }
    $iat = $now.ToUnixTimeSeconds()
    $header = [ordered]@{ typ = 'JWT'; alg = 'RS256'; kid = $connection.AppId } | ConvertTo-Json -Compress
    $payload = [ordered]@{ iss = 'enablebanking.com'; aud = 'api.enablebanking.com'; iat = $iat; exp = $iat + 3600 } |
        ConvertTo-Json -Compress
    $unsigned = (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($header))) + '.' +
        (ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($payload)))
    $signature = $connection.Rsa.SignData([Text.Encoding]::UTF8.GetBytes($unsigned),
        [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $connection.Jwt = "$unsigned.$(ConvertTo-Base64Url $signature)"
    $connection.JwtExpires = $now.AddSeconds(3600)
    $connection.Jwt
}
