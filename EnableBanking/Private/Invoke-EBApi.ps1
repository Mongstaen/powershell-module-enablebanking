# One call. Returns the answer as objects; an error stops with the status and
# Enable Banking's own code and message.
function Invoke-EBApi([string] $Method, [string] $Path, $Body = $null) {
    $params = @{
        Method = $Method
        Uri = "$script:Api$Path"
        Headers = @{ Authorization = "Bearer $(Get-EBToken)" }
        SkipHttpErrorCheck = $true
    }
    if ($null -ne $Body) {
        $params.Body = $Body | ConvertTo-Json -Depth 8 -Compress
        $params.ContentType = 'application/json'
    }
    $response = Invoke-WebRequest @params
    $content = if ($response.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($response.Content) } else { "$($response.Content)" }
    $answer = if ($content.Trim()) { $content | ConvertFrom-Json } else { $null }
    if ($response.StatusCode -ge 400) {
        $code = (Get-EBValue $answer 'error') ?? (Get-EBValue $answer 'code') ?? ''
        $message = (Get-EBValue $answer 'message') ?? (Get-EBValue $answer 'detail') ?? ''
        throw "Enable Banking answered $($response.StatusCode) to $Method ${Path}: $code $message".TrimEnd()
    }
    $answer
}
