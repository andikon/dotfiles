#Requires -Version 7.2
# Run through Verify-WezTerm.ps1 -Runtime; starts an isolated native mux without a GUI.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigurationDirectory,
    [Parameter(Mandatory)][string]$FixtureDirectory
)

$ErrorActionPreference = 'Stop'
$wezterm = (Get-Command wezterm -CommandType Application | Select-Object -First 1).Source
$server = Join-Path (Split-Path $wezterm -Parent) 'wezterm-mux-server.exe'
$shell = (Get-Command pwsh -CommandType Application | Select-Object -First 1).Source
$resultFile = Join-Path $FixtureDirectory 'runtime-result.json'
$configFile = Join-Path $ConfigurationDirectory 'wezterm.lua'
# JSON strings are valid Lua strings for these generated Windows paths after slash normalization.
$shellLua = ConvertTo-Json -InputObject $shell.Replace('\', '/') -Compress
$rootLua = ConvertTo-Json -InputObject $FixtureDirectory.Replace('\', '/') -Compress
$resultLua = ConvertTo-Json -InputObject $resultFile.Replace('\', '/') -Compress
$localLua = "return { shell = $shellLua, editor = 'cmd.exe', agent = 'cmd.exe', project_roots = { $rootLua .. '/Code' } }"
Set-Content -LiteralPath (Join-Path $ConfigurationDirectory 'local.lua') -Value $localLua
$hook = @'
config.unix_domains = { { name = 'workflow-runtime', socket_path = __ROOT__ .. '/mux.sock' } }
wezterm.on('mux-startup', function()
    local result = {}
    local ok, err = xpcall(function()
      -- The native mux supplies real panes; GUI action dispatch is covered separately.
      local actions, notices = 0, {}
      local window = {
        active_workspace = function() return 'runtime-a' end,
        perform_action = function() actions = actions + 1 end,
        toast_notification = function(_, _, message) notices[#notices + 1] = message end,
      }
      local initial_pane = {}
      local a = { workspace = 'runtime-a', path = __ROOT__, repository = 'runtime', branch = 'a' }
      local b = { workspace = 'runtime-b', path = __ROOT__, repository = 'runtime', branch = 'b' }
      local metadata = { [a.workspace] = a, [b.workspace] = b }
      wezterm.GLOBAL.dotfiles_projects = metadata
      projects.open(window, initial_pane, a)
      local function ids(workspace)
        local panes = {}
        for _, mux_window in ipairs(wezterm.mux.all_windows()) do
          if mux_window:get_workspace() == workspace then
            for _, tab in ipairs(mux_window:tabs()) do
              for _, pane in ipairs(tab:panes()) do panes[#panes + 1] = pane:pane_id() end
            end
          end
        end
        table.sort(panes)
        return panes
      end
      local original = ids(a.workspace)
      assert(#original == 3, 'Native API did not create the three-pane layout')
      projects.open(window, initial_pane, b)
      projects.open(window, initial_pane, a)
      assert(wezterm.json_encode(original) == wezterm.json_encode(ids(a.workspace)), 'Native return visit replaced panes')
      assert(#ids(b.workspace) == 3, 'Second workspace lost its panes')
      projects.pick(window, initial_pane, true, false)
      assert(#notices == 0, table.concat(notices, '\n'))
      assert(actions == 4, 'Workspace switch/selector actions were not generated')
      result.pane_ids = original
      result.second_workspace_panes = ids(b.workspace)
      result.ok = true
    end, tostring)
    if not ok then result.ok = false; result.error = err end
    local file = assert(io.open(__RESULT__, 'w'))
    file:write(wezterm.json_encode(result)); file:close()
end)
return config
'@
$hook = $hook.Replace('__ROOT__', $rootLua).Replace('__RESULT__', $resultLua)
$source = Get-Content -LiteralPath $configFile -Raw
Set-Content -LiteralPath $configFile -Value ($source -replace 'return config\s*$', $hook)
$runtimeProcess = $null
try {
    $runtimeLog = Join-Path $FixtureDirectory 'runtime-stderr.log'
    $runtimeProcess = Start-Process -FilePath $server -ArgumentList @('--config-file', ('"{0}"' -f $configFile)) -WindowStyle Hidden -PassThru -RedirectStandardError $runtimeLog
    $deadline = [DateTime]::UtcNow.AddSeconds(25)
    while (-not (Test-Path -LiteralPath $resultFile) -and [DateTime]::UtcNow -lt $deadline -and -not $runtimeProcess.HasExited) {
        Start-Sleep -Milliseconds 250
    }
    if (-not (Test-Path -LiteralPath $resultFile)) {
        $diagnostics = if (Test-Path -LiteralPath $runtimeLog) { Get-Content -LiteralPath $runtimeLog -Tail 25 }
        throw "WezTerm did not finish its isolated native mux check within 25 seconds. $diagnostics"
    }
    $result = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
    if (-not $result.ok) { throw "Native WezTerm runtime check failed: $($result.error)" }
    Write-Host 'PASS: native WezTerm mux creates two three-pane workspaces, reuses the same pane IDs and runs the project scanner.'
} finally {
    if ($runtimeProcess -and -not $runtimeProcess.HasExited) { Stop-Process -Id $runtimeProcess.Id -Force }
}
