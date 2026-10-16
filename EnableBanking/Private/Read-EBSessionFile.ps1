function Read-EBSessionFile {
    if (-not (Test-Path -LiteralPath $script:SessionFile)) { return [ordered]@{} }
    $text = Get-Content -Raw -LiteralPath $script:SessionFile
    if (-not $text.Trim()) { return [ordered]@{} }
    $text | ConvertFrom-Json -AsHashtable
}
