# A property's value, or $null when the object or the property is missing (strict mode
# would otherwise stop at the first answer without it).
function Get-EBValue($Object, [string] $Name) {
    if ($null -eq $Object) { return $null }
    $Object.PSObject.Properties[$Name]?.Value
}
