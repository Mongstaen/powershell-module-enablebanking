# The saved session for a bank name or wildcard pattern.
function Find-EBSession([string] $Bank) {
    $sessions = Read-EBSessionFile
    $found = @($sessions.Keys | Where-Object { $_ -like $Bank })
    if ($found.Count -eq 1) { return $sessions[$found[0]] }
    $known = if ($sessions.Count) { $sessions.Keys -join ', ' } else { 'none; log in with New-EBSession' }
    if (-not $found.Count) { throw "No saved session for '$Bank'. Saved: $known." }
    throw "'$Bank' matches several saved sessions: $($found -join ', '). Be more precise."
}
