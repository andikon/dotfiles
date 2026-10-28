#Requires -Version 7.2
[CmdletBinding()]
param(
    [string]$RootsJson = (ConvertTo-Json -InputObject @((Join-Path $env:USERPROFILE 'Code')) -Compress),
    [ValidateRange(0, 12)][int]$MaxDepth = 4,
    [string]$CacheDirectory = (Join-Path $env:LOCALAPPDATA 'wezterm/project-index'),
    [string]$CacheFile
)

$ErrorActionPreference = 'Stop'
$roots = @($RootsJson | ConvertFrom-Json)
$normalizedRoots = @($roots | ForEach-Object { $_.Replace('\', '/').TrimEnd('/') })
$signature = "projects-v2`n$MaxDepth`n" + ($normalizedRoots -join "`n")
if (-not $CacheFile) {
    [uint64]$hash = 5381
    foreach ($value in [Text.Encoding]::UTF8.GetBytes($signature)) { $hash = ($hash * 33 + $value) % 4294967296 }
    $CacheFile = Join-Path $CacheDirectory ('projects-{0:x8}.json' -f $hash)
}
$CacheFile = [IO.Path]::GetFullPath($CacheFile)
New-Item -ItemType Directory -Path (Split-Path $CacheFile -Parent) -Force | Out-Null
$lock = $null
$temporary = $CacheFile + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
try {
    try { $lock = [IO.File]::Open("$CacheFile.lock", 'OpenOrCreate', 'ReadWrite', 'None') }
    catch [IO.IOException] { return } # Another WezTerm instance is already indexing these roots.
    $result = @{ signature = $signature; generation = [guid]::NewGuid().ToString('N'); time = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); projects = @(); warnings = @(); error = '' }
    try {
        $catalog = & (Join-Path $PSScriptRoot 'Get-Projects.ps1') -RootsJson $RootsJson -MaxDepth $MaxDepth | ConvertFrom-Json
        $result.projects = @($catalog.projects)
        $result.warnings = @($catalog.warnings)
    } catch {
        $result.error = $_.Exception.Message
        # A transient failure must not erase the last good project list.
        if (Test-Path -LiteralPath $CacheFile -PathType Leaf) {
            try {
                $previous = Get-Content -LiteralPath $CacheFile -Raw | ConvertFrom-Json
                if ($previous.signature -eq $signature) { $result.projects = @($previous.projects) }
            } catch { }
        }
    }
    $result.time = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    [IO.File]::WriteAllText($temporary, ($result | ConvertTo-Json -Depth 6 -Compress), [Text.UTF8Encoding]::new($false))
    # Readers see either the old complete index or the new complete index.
    [IO.File]::Move($temporary, $CacheFile, $true)
    Write-Output $CacheFile
} finally {
    if ($lock) { $lock.Dispose() }
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
}
