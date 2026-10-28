function gs { git status }
function ga { git add . }
function gp { git push }
function gc {
    param($m)
    git add .
    git commit -m $m
}

function gclean {
	param(
    [switch]$WhatIf
	)

	# Ensure we're in a git repo
	git rev-parse --is-inside-work-tree 2>$null | Out-Null
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Not inside a git repository."
		exit 1
	}

	# Update remote refs
	git fetch --all --prune | Out-Null

	$currentBranch = git branch --show-current

	# Branches you NEVER want to delete
	$protectedBranches = @(
		"main",
		"master",
		"develop",
		$currentBranch
	)

	# Get local branches with no upstream
	$branches = git for-each-ref `
		--format="%(refname:short) %(upstream:short)" `
		refs/heads |
		Where-Object {
			$parts = $_ -split " "
			$branch = $parts[0]
			$upstream = $parts[1]

			-not $upstream -and
			-not ($protectedBranches -contains $branch)
		} |
		ForEach-Object { ($_ -split " ")[0] }

	if (-not $branches) {
		Write-Host "No local untracked branches found."
		return
	}

	Write-Host "Branches to be deleted:"
	$branches | ForEach-Object { Write-Host "  $_" }

	if ($WhatIf) {
		Write-Host "`n(WhatIf mode — nothing deleted)"
		return
	}

	foreach ($branch in $branches) {
		git branch -d $branch
	}

}

Export-ModuleMember -Function *
