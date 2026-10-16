function Write-EBSessionFile($Sessions) {
    New-Item -ItemType Directory -Force -Path (Split-Path $script:SessionFile) | Out-Null
    $Sessions | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:SessionFile
}
