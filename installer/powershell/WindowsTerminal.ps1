function ConvertFrom-DotfilesTerminalJson([string]$Text) {
    # Terminal settings are JSONC. Strip comments/trailing commas only outside strings,
    # rather than using regexes that corrupt URLs, escaped quotes or command lines.
    $clean = New-Object Text.StringBuilder
    $quoted = $false; $escaped = $false
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $character = $Text[$i]
        if ($quoted) {
            [void]$clean.Append($character)
            if ($escaped) { $escaped = $false }
            elseif ($character -eq '\') { $escaped = $true }
            elseif ($character -eq '"') { $quoted = $false }
        } elseif ($character -eq '"') {
            $quoted = $true; [void]$clean.Append($character)
        } elseif ($character -eq '/' -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq '/') {
            [void]$clean.Append(' ')
            $i += 2
            while ($i -lt $Text.Length -and $Text[$i] -ne "`n" -and $Text[$i] -ne "`r") { $i++ }
            $i--
        } elseif ($character -eq '/' -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq '*') {
            $end = $Text.IndexOf('*/', $i + 2, [StringComparison]::Ordinal)
            if ($end -lt 0) { throw 'Unterminated JSONC comment.' }
            [void]$clean.Append(' '); $i = $end + 1
        } else { [void]$clean.Append($character) }
    }
    $textWithoutComments = $clean.ToString()
    $clean = New-Object Text.StringBuilder
    $quoted = $false; $escaped = $false
    for ($i = 0; $i -lt $textWithoutComments.Length; $i++) {
        $character = $textWithoutComments[$i]
        if ($quoted) {
            [void]$clean.Append($character)
            if ($escaped) { $escaped = $false }
            elseif ($character -eq '\') { $escaped = $true }
            elseif ($character -eq '"') { $quoted = $false }
            continue
        }
        if ($character -eq '"') { $quoted = $true }
        if ($character -eq ',') {
            $next = $i + 1
            while ($next -lt $textWithoutComments.Length -and [char]::IsWhiteSpace($textWithoutComments[$next])) { $next++ }
            if ($next -lt $textWithoutComments.Length -and $textWithoutComments[$next] -in @('}', ']')) { continue }
        }
        [void]$clean.Append($character)
    }
    $json = $clean.ToString().Trim()
    if (-not $json.StartsWith('{')) { throw 'Terminal settings must be a JSON object.' }
    $settings = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    if ($settings -isnot [pscustomobject]) { throw 'Terminal settings must be a JSON object.' }
    return $settings
}

function Merge-DotfilesTerminalObject($Existing, $Managed) {
    foreach ($property in $Managed.PSObject.Properties) {
        $previous = $Existing.PSObject.Properties[$property.Name]
        if ($previous -and $previous.Value -is [pscustomobject] -and $property.Value -is [pscustomobject]) {
            Merge-DotfilesTerminalObject $previous.Value $property.Value
        } else { $Existing | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force }
    }
}

function Write-DotfilesTerminalSettings([string]$Source, [string]$Destination, [string]$Stage) {
    $managed = ConvertFrom-DotfilesTerminalJson ([IO.File]::ReadAllText($Source))
    if ($managed.profiles.PSObject.Properties['list'] -or $managed.PSObject.Properties['defaultProfile'] -or $managed.PSObject.Properties['disabledProfileSources']) {
        throw 'Repository Terminal settings must not define machine profiles or profile selection.'
    }
    if (-not (Test-DotfilesEntry $Destination)) { return }
    try { $existing = ConvertFrom-DotfilesTerminalJson ([IO.File]::ReadAllText($Destination)) }
    catch { throw "Cannot safely read Windows Terminal settings at $Destination. Repair the JSONC or restore a backup; the original file was left untouched." }
    if ($existing.PSObject.Properties['profiles']) {
        if ($existing.profiles -is [array]) {
            # Old Terminal releases stored the profile list directly in profiles.
            $existing.profiles = [pscustomobject]@{ list = $existing.profiles }
        } elseif ($existing.profiles -isnot [pscustomobject]) { throw 'Existing Terminal profiles must be an object or legacy array; original file was left untouched.' }
        if ($existing.profiles.PSObject.Properties['list'] -and $existing.profiles.list -isnot [array]) { throw 'Existing Terminal profile list must be an array; original file was left untouched.' }
    }
    # A profile can reference a custom scheme, so retain schemes not owned by the repo.
    if ($existing.PSObject.Properties['schemes']) {
        $ownedNames = @($managed.schemes | ForEach-Object name)
        $managed.schemes = @($existing.schemes | Where-Object { $_.name -notin $ownedNames }) + @($managed.schemes)
    }
    Merge-DotfilesTerminalObject $existing $managed
    $json = ConvertTo-Json -InputObject $existing -Depth 100 -WarningAction Stop
    [IO.File]::WriteAllText($Stage, $json, (New-Object Text.UTF8Encoding($false)))
}
