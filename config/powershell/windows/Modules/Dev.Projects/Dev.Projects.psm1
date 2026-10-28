function proj {

    $projectsRoot = Join-Path $HOME "projects"
    $curprojFile  = Join-Path $projectsRoot ".curproj"

    if (-not (Test-Path $projectsRoot)) {
        Write-Host "Projects folder not found: $projectsRoot"
        return
    }

    $projects = Get-ChildItem $projectsRoot -Directory
    if (-not $projects) {
        Write-Host "No projects found."
        return
    }

    if (Test-Path $curprojFile) {
        $targetName = (Get-Content $curprojFile -Raw).Trim()
        if ($targetName) {
            $matches = $projects | Where-Object Name -eq $targetName
            if ($matches.Count -eq 1) {
                Set-Location $matches[0].FullName
                return
            }
        }
    }

    $selected = $projects.FullName |
        Out-GridView -Title "Select a project" -PassThru

    if ($selected) {
        Set-Location $selected
    }
}

Export-ModuleMember -Function proj
