function prompt {

    function Write-Colored($text, $color) {
        Write-Host $text -NoNewline -ForegroundColor $color
    }

    function Get-TruncatedPath {
        $path = (Get-Location).Path

        # If inside git repo, truncate to repo root
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            $path = $path.Substring($gitRoot.Length).TrimStart('\')
            $repoName = Split-Path $gitRoot -Leaf
            $path = Join-Path $repoName $path
        }

        $parts = $path -split '[\\/]' | Where-Object { $_ }
        if ($parts.Count -gt 3) {
            $parts = $parts[-3..-1]
        }

        ($parts -join '/')
    }

    # directory
    Write-Colored (Get-TruncatedPath) Cyan

    # read-only indicator
    if (-not (Test-Path . -PathType Container -ErrorAction SilentlyContinue)) {
        Write-Colored " " DarkGray
    }

    # git info
    $branch = git branch --show-current 2>$null
    if ($branch) {
        Write-Host " " -NoNewline
        Write-Colored " $branch" Yellow

        $status = git status --porcelain 2>$null
        if ($status) {
            $staged   = ($status | Where-Object { $_ -match '^[AM]' }).Count
            $modified = ($status | Where-Object { $_ -match '^.[MT]' }).Count
            $deleted  = ($status | Where-Object { $_ -match '^.[D]' }).Count

            Write-Host " (" -NoNewline
            if ($staged)   { Write-Colored "+$staged " Green }
            if ($modified) { Write-Colored "~$modified " Yellow }
            if ($deleted)  { Write-Colored "-$deleted " Red }
            Write-Host ")" -NoNewline
        }
    }

    Write-Host ""
    Write-Colored "_ " Green

    return " "
}

Export-ModuleMember -Function prompt
