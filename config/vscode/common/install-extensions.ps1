# Optional manual entry point. The wizard also offers these as a dependency.
$ErrorActionPreference = 'Stop'
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'extensions.txt') | ForEach-Object {
    if ($_.Trim()) {
        code --install-extension $_.Trim()
        if ($LASTEXITCODE -ne 0) { throw "Could not install extension $_" }
    }
}
