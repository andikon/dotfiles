. (Join-Path $PSScriptRoot 'WindowsTerminal.ps1')

function Test-DotfilesEntry([string]$Path) {
    return $null -ne (Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue)
}

function Test-DotfilesLink($Item) {
    # Cloud-backed files can have ReparsePoint without redirecting a path.
    return $Item -and $Item.LinkType -in @('SymbolicLink', 'Junction')
}

function Assert-DotfilesTarget($Context, [string]$Path) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
    if ($full.IndexOfAny([char[]]"`t`r`n") -ge 0) { throw 'Configuration paths cannot contain tabs or newlines.' }
    $inside = $false
    foreach ($root in $Context.Allowed) {
        $resolvedRoot = [IO.Path]::GetFullPath($root).TrimEnd('\', '/')
        if ($full.StartsWith($resolvedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { $inside = $true }
        if ($full -eq $resolvedRoot) { throw "Refusing to replace a configuration root: $full" }
    }
    if (-not $inside) { throw "Destination is outside the allowed configuration locations: $full" }
    $state = [IO.Path]::GetFullPath($Context.State).TrimEnd('\', '/')
    $backups = Join-Path $state 'backups'
    if ($full -eq $state -or $state.StartsWith($full + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or $full -eq $backups -or $full.StartsWith($backups + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Destination overlaps installer backup state: $full" }
    $repository = $Context.Root.TrimEnd('\', '/')
    if ($full -eq $repository -or $full.StartsWith($repository + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or $repository.StartsWith($full + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Destination overlaps the source repository: $full"
    }
    $parent = Split-Path $full -Parent
    while ($parent) {
        $item = Get-Item -LiteralPath $parent -Force -ErrorAction SilentlyContinue
        if (Test-DotfilesLink $item) { throw "A destination parent is a link or junction: $parent. Choose a physical destination." }
        $next = Split-Path $parent -Parent
        if ($next -eq $parent) { break }
        $parent = $next
    }
    return $full
}

function Remove-DotfilesEntry($Context, [string]$Path) {
    $full = Assert-DotfilesTarget $Context $Path
    $item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
    if (-not $item) { return }
    if (Test-DotfilesLink $item) {
        if ($item.PSIsContainer) { [IO.Directory]::Delete($full) } else { [IO.File]::Delete($full) }
    } elseif ($item.PSIsContainer) {
        foreach ($child in Get-ChildItem -LiteralPath $full -Force) { Remove-DotfilesEntry $Context $child.FullName }
        [IO.Directory]::Delete($full)
    } else { Remove-Item -LiteralPath $full -Force }
}

function Write-DotfilesJournal($Run) {
    $text = ConvertTo-Json -InputObject $Run.Journal -Depth 8
    [IO.File]::WriteAllText(($Run.Manifest + '.tmp'), $text, (New-Object Text.UTF8Encoding($false)))
    if (Test-Path -LiteralPath $Run.Manifest -PathType Leaf) {
        [IO.File]::Replace(($Run.Manifest + '.tmp'), $Run.Manifest, [NullString]::Value)
    } else { Move-Item -LiteralPath ($Run.Manifest + '.tmp') -Destination $Run.Manifest }
}

function New-DotfilesRun($Context) {
    $name = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $directory = Join-Path $Context.State "backups/$name"
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $run = [pscustomobject]@{ Directory = $directory; Manifest = (Join-Path $directory 'manifest.json'); Journal = [pscustomobject]@{ Version = 1; Home = $Context.Home; Entries = @() } }
    Write-DotfilesJournal $run
    return $run
}

function Undo-DotfilesEntry($Context, $Entry) {
    $target = Assert-DotfilesTarget $Context $Entry.Destination
    if ($Entry.Status -eq 'intent' -and $Entry.Existed -and (Test-DotfilesEntry $target)) {
        # A failed cross-volume copy may leave a partial backup beside an intact original.
        $Entry.Status = 'rolled-back'
        return
    }
    if (Test-DotfilesEntry $Entry.Backup) {
        Remove-DotfilesEntry $Context $target
        Move-Item -LiteralPath $Entry.Backup -Destination $target
    } elseif (-not $Entry.Existed -and $Entry.Status -in @('intent', 'backed-up', 'installed')) {
        Remove-DotfilesEntry $Context $target
    }
    $Entry.Status = 'rolled-back'
}

function Install-DotfilesTool($Context, $Run, [string]$Tool) {
    $prepared = @()
    $entries = @()
    try {
        foreach ($target in @(Get-DotfilesTargets $Context $Tool)) {
            $destination = Assert-DotfilesTarget $Context $target.Destination
            $stage = $null
            if ($target.Kind -ne 'absent') {
                if (-not (Test-Path -LiteralPath $target.Source)) { throw "Missing configuration source: $($target.Source)" }
                if (Test-DotfilesLink (Get-Item -LiteralPath $target.Source -Force)) { throw "Configuration source is a link: $($target.Source)" }
                $links = @(Get-ChildItem -LiteralPath $target.Source -Force -Recurse -ErrorAction Stop | Where-Object { Test-DotfilesLink $_ })
                if ($links.Count) { throw "Configuration source contains links: $($target.Source)" }
                New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
                $stage = Join-Path (Split-Path $destination -Parent) ('.dotfiles-stage-' + [guid]::NewGuid().ToString('N'))
            }
            $prepared += [pscustomobject]@{ Target = $target; Destination = $destination; Stage = $stage }
            if ($stage) { Copy-Item -LiteralPath $target.Source -Destination $stage -Recurse -Force }
            if ($stage -and $Tool -eq 'windows-terminal') { Write-DotfilesTerminalSettings $target.Source $destination $stage }
            if ($stage -and $Tool -eq 'wezterm' -and -not $Context.Portable -and (Test-DotfilesEntry (Join-Path $stage 'local.lua'))) { Remove-DotfilesEntry $Context (Join-Path $stage 'local.lua') }
        }
        foreach ($item in $prepared) {
            $index = $Run.Journal.Entries.Count
            $backup = Join-Path $Run.Directory ("{0:D3}-{1}/previous" -f $index, $Tool)
            $entry = [pscustomobject]@{ Tool = $Tool; Destination = $item.Destination; Backup = $backup; Existed = (Test-DotfilesEntry $item.Destination); Status = 'intent' }
            $Run.Journal.Entries += $entry
            $entries += $entry
            Write-DotfilesJournal $Run
            if ($entry.Existed) {
                New-Item -ItemType Directory -Path (Split-Path $backup -Parent) -Force | Out-Null
                # Moving the entry also preserves a legacy Stow symlink itself.
                Move-Item -LiteralPath $item.Destination -Destination $backup
            }
            $entry.Status = 'backed-up'
            Write-DotfilesJournal $Run
            if ($item.Stage) { Move-Item -LiteralPath $item.Stage -Destination $item.Destination }
            $entry.Status = 'installed'
            Write-DotfilesJournal $Run
        }
    } catch {
        $failure = $_
        [array]::Reverse($entries)
        foreach ($entry in $entries) {
            try { Undo-DotfilesEntry $Context $entry } catch { Write-Warning "Automatic rollback failed for $($entry.Destination). Backup: $($entry.Backup). $_" }
        }
        Write-DotfilesJournal $Run
        throw $failure
    } finally {
        foreach ($item in $prepared) { if ($item.Stage -and (Test-DotfilesEntry $item.Stage)) { Remove-DotfilesEntry $Context $item.Stage } }
    }
}

function Restore-DotfilesRun($Context, [string]$Directory, [bool]$DryRun) {
    $directoryPath = [IO.Path]::GetFullPath($Directory)
    $backupRoot = [IO.Path]::GetFullPath((Join-Path $Context.State 'backups')).TrimEnd('\', '/')
    if (-not $directoryPath.StartsWith($backupRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Restore must name a run inside $backupRoot" }
    $manifest = Join-Path $directoryPath 'manifest.json'
    $journal = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
    if ($journal.Version -ne 1 -or $journal.Home -ne $Context.Home) { throw 'Backup version or home directory does not match.' }
    $entries = @($journal.Entries)
    [array]::Reverse($entries)
    # Validate the complete journal before touching any destination.
    foreach ($entry in $entries) {
        [void](Assert-DotfilesTarget $Context $entry.Destination)
        $backup = [IO.Path]::GetFullPath($entry.Backup)
        if (-not $backup.StartsWith($directoryPath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Backup entry escapes its run directory.' }
        if ($entry.Status -in @('installed', 'backed-up') -and $entry.Existed -and -not (Test-DotfilesEntry $backup)) { throw "Missing backup: $backup" }
        if ($entry.Status -eq 'intent' -and $entry.Existed -and -not (Test-DotfilesEntry $backup) -and -not (Test-DotfilesEntry $entry.Destination)) { throw "Interrupted backup has neither original nor saved target: $($entry.Destination)" }
    }
    $run = [pscustomobject]@{ Directory = $directoryPath; Manifest = $manifest; Journal = $journal }
    foreach ($entry in $entries) {
        if ($entry.Status -in @('restored', 'rolled-back')) { continue }
        Write-Host "Restore $($entry.Destination)"
        if ($DryRun) { continue }
        if ($entry.Status -eq 'intent' -and $entry.Existed -and (Test-DotfilesEntry $entry.Destination)) {
            $entry.Status = 'restored'
            Write-DotfilesJournal $run
            continue
        }
        if ($entry.Existed -and -not (Test-DotfilesEntry $entry.Backup)) { continue } # Intent was recorded before a move.
        $saved = $null
        if (Test-DotfilesEntry $entry.Destination) {
            $saved = Join-Path (Split-Path $entry.Backup -Parent) 'replaced-on-restore'
            New-Item -ItemType Directory -Path (Split-Path $saved -Parent) -Force | Out-Null
            if (Test-DotfilesEntry $saved) { throw "Restore already has a saved current configuration: $saved" }
            Move-Item -LiteralPath $entry.Destination -Destination $saved
        }
        if ($entry.Existed) {
            try { Move-Item -LiteralPath $entry.Backup -Destination $entry.Destination }
            catch {
                if ($saved -and (Test-DotfilesEntry $saved) -and -not (Test-DotfilesEntry $entry.Destination)) { Move-Item -LiteralPath $saved -Destination $entry.Destination }
                throw
            }
        }
        $entry.Status = 'restored'
        Write-DotfilesJournal $run
    }
}
