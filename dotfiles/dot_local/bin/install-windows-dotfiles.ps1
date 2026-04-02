<#
    Installs Windows-specific dotfiles from this repo into their expected locations
    AND installs all required Windows dependencies via winget.

    Covers:
      - GlazeWM     -> $GlazePath (defaults: $env:LOCALAPPDATA\glaze-wm)
      - Neovim      -> $NeovimPath (defaults: $env:LOCALAPPDATA\nvim)
      - PowerShell  -> $PowerShellProfile (defaults: $PROFILE)
      - Starship    -> $StarshipPath (defaults: $env:APPDATA\starship.toml)
      - Zebar       -> $ZebarPath (defaults: $env:LOCALAPPDATA\zebar)
      - JetBrains IDEA (optional) -> $IdeaPath (defaults: $env:APPDATA\JetBrains)

    Usage (from repo root):
      pwsh -File .\scripts\install-windows-dotfiles.ps1

    You can override any target path via parameters, e.g.:
      pwsh -File .\scripts\install-windows-dotfiles.ps1 -NeovimPath "$HOME\.config\nvim"
#>

[CmdletBinding()]
param(
    [string]$GlazePath = (Join-Path $env:LOCALAPPDATA 'glaze-wm'),
    [string]$NeovimPath = (Join-Path $env:LOCALAPPDATA 'nvim'),
    [string]$PowerShellProfile = $PROFILE,
    [string]$StarshipPath = (Join-Path $env:USERPROFILE '.config\starship.toml'),
    [string]$ZebarPath = (Join-Path $env:LOCALAPPDATA 'zebar'),
    [string]$IdeaPath = (Join-Path $env:USERPROFILE 'JetBrains')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve repo root (this script lives in /scripts)
$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir '..')

function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Warn { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Info "Creating $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-Dir {
    param(
        [string]$Name,
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path $Source)) {
        Write-Warn "Skip ${Name}: source missing at $Source"
        return
    }

    Ensure-Dir $Destination
    Write-Info "Syncing $Name -> $Destination"
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force
}

function Copy-File {
    param(
        [string]$Name,
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path $Source)) {
        Write-Warn "Skip ${Name}: source missing at $Source"
        return
    }

    $destDir = Split-Path -Parent $Destination
    Ensure-Dir $destDir
    Write-Info "Copying $Name -> $Destination"
    Copy-Item -Path $Source -Destination $Destination -Force
}

function Install-WingetDependencies {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn "winget is not available. Skipping dependency installation. Install 'App Installer' from the Microsoft Store to enable this."
        return
    }

    $Packages = @(
        # --- Core editor / CLI tools ---
        @{ Name = "Neovim";          Id = "Neovim.Neovim" },
        @{ Name = "Git";             Id = "Git.Git" },
        @{ Name = "ripgrep";         Id = "BurntSushi.ripgrep.MSVC" },
        @{ Name = "fd";              Id = "sharkdp.fd" },
        @{ Name = "fzf";             Id = "junegunn.fzf" },
        @{ Name = "Starship";        Id = "Starship.Starship" },
        @{ Name = "win32yank";       Id = "equalsraf.win32yank" },

        # --- Window manager / bar / terminal ---
        @{ Name = "GlazeWM";         Id = "GlazeWM.GlazeWM" },
        @{ Name = "Zebar";           Id = "Zebar.Zebar" },          # Adjust if winget ID changes
        @{ Name = "Windows Terminal";Id = "Microsoft.WindowsTerminal" },
        @{ Name = "kitty";           Id = "kovidgoyal.kitty" },     # Kitty terminal

        # --- Shell / runtimes ---
        @{ Name = "PowerShell 7";    Id = "Microsoft.PowerShell" },
        @{ Name = "Node.js LTS";     Id = "OpenJS.NodeJS.LTS" },
        @{ Name = "Python 3";        Id = "Python.Python.3" },

        # --- IDE / fonts ---
        @{ Name = "IntelliJ IDEA (Community)"; Id = "JetBrains.IntelliJIDEA.Community" },
        @{ Name = "JetBrains Mono Nerd Font";  Id = "JetBrains.JetBrainsMonoNerdFont" }
    )

    function Install-Package {
        param(
            [string]$Name,
            [string]$Id
        )

        Write-Info "Checking $Name ($Id)"

        $listed = winget list --id $Id --exact 2>$null
        if ($LASTEXITCODE -eq 0 -and $listed -and -not ($listed -match "No installed package found")) {
            Write-Info "$Name already installed, skipping."
            return
        }

        Write-Info "Installing $Name..."
        winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
    }

    Write-Info "Installing Windows dependencies via winget..."
    foreach ($pkg in $Packages) {
        Install-Package -Name $pkg.Name -Id $pkg.Id
    }
}

function Install-Dotfiles {
    # GlazeWM (config.yaml)
    $GlazeSource = Join-Path $RepoRoot '.config\glazewm'
    Copy-Dir -Name 'GlazeWM config' -Source $GlazeSource -Destination $GlazePath

    # Neovim config
    $NvimSource = Join-Path $RepoRoot '.config\nvim'
    Copy-Dir -Name 'Neovim config' -Source $NvimSource -Destination $NeovimPath

    # PowerShell profile
    $PsProfileSource = Join-Path $RepoRoot '.config\powershell\profile.ps1'
    Copy-File -Name 'PowerShell profile' -Source $PsProfileSource -Destination $PowerShellProfile

    # Starship config
    $StarshipSource = Join-Path $RepoRoot '.config\starship.toml'
    Copy-File -Name 'Starship config' -Source $StarshipSource -Destination $StarshipPath

    # Zebar config (assumes Zebar reads from %LOCALAPPDATA%\zebar)
    $ZebarSource = Join-Path $RepoRoot '.config\zebar'
    Copy-Dir -Name 'Zebar config' -Source $ZebarSource -Destination $ZebarPath

    # JetBrains IDEA (optional; left generic because versions differ)
    $IdeaSource = Join-Path $RepoRoot '.config\idea'
    if (Test-Path $IdeaSource) {
        Copy-Dir -Name 'JetBrains IDEA config (generic)' -Source $IdeaSource -Destination $IdeaPath
    } else {
        Write-Warn "Skip IDEA: source folder not found ($IdeaSource)"
    }
}

Install-WingetDependencies
Install-Dotfiles

Write-Host "`nAll done (dependencies + dotfiles)." -ForegroundColor Green
