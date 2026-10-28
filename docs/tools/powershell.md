# PowerShell workflow

The profile imports the bundled `Dev.Git`, `Dev.FS`, `Dev.Docker`, `Dev.Projects` and `Dev.Prompt` modules. Install it with `./install.ps1 -Only powershell`, then reopen PowerShell. The installer owns these named modules; unrelated modules stay in place.

## Git worktrees

Run **`gwt`** inside a Git checkout or any of its subdirectories. It uses native PowerShell prompts and installed Git, and works independently of WezTerm. PowerShell 5.1 and 7 are supported.

```powershell
gwt                                      # Interactive creation
gwt feature/login                        # New branch from the current HEAD
gwt feature/login -Base main              # New branch from a local branch
gwt review/pr-123 -Base origin/feature/login -Fetch
gwt -Existing feature/already-local       # An existing local branch
gwt feature/search -Path 'D:\Work\search' -Enter
gwt feature/search -WhatIf                # Preview without creating anything
```

The interactive command offers an optional fetch, new or existing local branch, and a starting point for a new branch: current HEAD, a local branch, or a remote-tracking branch. Choose numbered entries; blank cancels selection prompts. It shows the destination, accepts an override, and asks for confirmation before creation. At the destination prompt, blank accepts the suggestion. Creation confirmation defaults to No.

For PR review, `-Base origin/feature/login` creates your new **local** review branch at that remote-tracking branch's commit. `-Fetch` runs `git fetch --all` first. Without it, the command uses refs already available locally. The source may also be an existing commit or tag. For fork PRs, fetch the fork branch or PR ref into your local repository first, then use that ref as the base.

Destinations default to `<main-checkout>.worktrees/<branch-folder>`. For example, `C:\Code\myapp` with branch `feature/login` creates `C:\Code\myapp.worktrees\feature-login`. Running from a linked worktree still uses the main checkout to calculate this location. Slashes and Windows-invalid filename characters become hyphens; colliding folders require another `-Path`. Existing destinations are never reused or replaced.

The wrapper rejects invalid names, missing starting refs and existing new-branch names. If an existing branch is already checked out, it reports that checkout's path. Creation leaves your current directory unchanged unless you supply `-Enter`, and returns an object containing `Branch`, `Path` and `Base`. `-WhatIf` skips both fetching and creation. Outside a checkout, errors return to PowerShell without closing it.

The implementation is `New-GitWorktree.ps1` beside `Dev.Git.psm1`. You can invoke that script directly with the same parameters without importing the profile. It does not switch WezTerm projects, install dependencies or run project startup commands. [WezTerm's picker](wezterm.md#projects-and-worktrees) discovers registered worktrees through its normal refresh. Closing a terminal project leaves its checkout and branch on disk.

## Verification

```powershell
pwsh -NoProfile -File tests/powershell/Test-GitWorktree.ps1
powershell -NoProfile -File tests/powershell/Test-GitWorktree.ps1
```

These checks create disposable repositories and a local bare remote. They exercise real Git operations without accessing hosted repositories or changing your active profile.
