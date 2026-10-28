local wezterm = require 'wezterm'
local act = wezterm.action
local M = {}

local function notify(window, message)
  wezterm.log_warn(message)
  window:toast_notification('Projects', message, nil, 6000)
end

local function live_workspaces()
  local result = {}
  for _, name in ipairs(wezterm.mux.get_workspace_names()) do
    result[name] = true
  end
  return result
end

function M.setup(options)
  local script_dir = wezterm.config_dir .. '/scripts/'

  local function pane_args(role)
    return {
      options.shell, '-NoLogo', '-NoExit', '-File', script_dir .. 'Start-Pane.ps1',
      '-Role', role, '-Program', role == 'editor' and options.editor or options.agent,
    }
  end

  local function catalog(window, refresh)
    local signature = wezterm.json_encode { options.project_roots, options.max_depth }
    local cached = wezterm.GLOBAL.dotfiles_catalog
    if not refresh and cached and cached.signature == signature
        and os.time() - cached.time < options.cache_seconds then
      return cached.projects
    end
    local ok, stdout, stderr = wezterm.run_child_process {
      options.shell, '-NoLogo', '-NoProfile', '-NonInteractive', '-File',
      script_dir .. 'Get-Projects.ps1', '-RootsJson', wezterm.json_encode(options.project_roots),
      '-MaxDepth', tostring(options.max_depth),
    }
    if not ok then
      notify(window, 'Project scan failed. Check PowerShell 7 and Git on PATH. ' .. (stderr or ''))
      return cached and cached.projects or {}
    end
    local decoded, result = pcall(wezterm.json_parse, stdout)
    if not decoded or type(result) ~= 'table' or type(result.projects) ~= 'table' then
      notify(window, 'The project scanner did not return a valid catalog.')
      return cached and cached.projects or {}
    end
    if result.warnings and #result.warnings > 0 then
      notify(window, table.concat(result.warnings, '\n'))
    end
    wezterm.GLOBAL.dotfiles_catalog = { signature = signature, time = os.time(), projects = result.projects }
    -- Retain metadata for live workspaces even if a later scan no longer finds their root.
    local known = wezterm.GLOBAL.dotfiles_projects or {}
    for _, project in ipairs(result.projects) do
      known[project.workspace] = project
    end
    wezterm.GLOBAL.dotfiles_projects = known
    return result.projects
  end

  function M.open(window, pane, project)
    if live_workspaces()[project.workspace] then
      window:perform_action(act.SwitchToWorkspace { name = project.workspace }, pane)
      return
    end
    local ok, err = pcall(function()
      local tab, editor = wezterm.mux.spawn_window {
        workspace = project.workspace, cwd = project.path, args = pane_args('editor'),
      }
      tab:set_title(project.repository .. ' / ' .. project.branch)
      window:perform_action(act.SwitchToWorkspace { name = project.workspace }, pane)
      local agent = editor:split {
        direction = 'Right', size = 0.38, cwd = project.path, args = pane_args('agent'),
      }
      agent:split {
        direction = 'Bottom', size = 0.35, cwd = project.path, args = { options.shell, '-NoLogo' },
      }
      editor:activate()
    end)
    if not ok then notify(window, 'Could not open project: ' .. tostring(err)) end
  end

  function M.pick(window, pane, refresh, running_only)
    -- Scanning happens only on request, never during config evaluation or status updates.
    local disk = running_only and {} or catalog(window, refresh)
    local live = live_workspaces()
    local known = wezterm.GLOBAL.dotfiles_projects or {}
    local entries, seen = {}, {}
    for _, project in ipairs(disk) do
      entries[#entries + 1] = project
      seen[project.workspace] = true
    end
    for name in pairs(live) do
      if not seen[name] then
        entries[#entries + 1] = known[name] or { workspace = name, repository = name, branch = '', path = '' }
      end
    end
    local active = window:active_workspace()
    table.sort(entries, function(a, b)
      if (a.workspace == active) ~= (b.workspace == active) then return a.workspace == active end
      if (live[a.workspace] == true) ~= (live[b.workspace] == true) then return live[a.workspace] == true end
      return (a.repository .. a.branch .. a.path):lower() < (b.repository .. b.branch .. b.path):lower()
    end)
    local choices, by_id = {}, {}
    for _, project in ipairs(entries) do
      local marker = project.workspace == active and '●' or (live[project.workspace] and '◉' or '○')
      local path = project.path
      local home = wezterm.home_dir:gsub('\\', '/')
      if path:sub(1, #home):lower() == home:lower() then path = '~' .. path:sub(#home + 1) end
      choices[#choices + 1] = {
        id = project.workspace,
        label = wezterm.format {
          { Foreground = { Color = live[project.workspace] and '#a4be8c' or '#687386' } },
          { Text = marker .. '  ' },
          { Foreground = { Color = '#c9d1df' } }, { Attribute = { Intensity = 'Bold' } },
          { Text = project.repository }, { Attribute = { Intensity = 'Normal' } },
          { Foreground = { Color = '#b39ddb' } },
          { Text = project.branch ~= '' and ('  /  ' .. project.branch) or '' },
          { Foreground = { Color = '#687386' } }, { Text = path ~= '' and ('    ' .. path) or '' },
        },
      }
      by_id[project.workspace] = project
    end
    if #choices == 0 then
      notify(window, 'No projects found. Set project_roots in local.lua, then refresh with Ctrl+a Shift+f.')
      return
    end
    window:perform_action(act.InputSelector {
      title = running_only and 'Running workspaces' or 'Projects & worktrees',
      description = 'Enter open · Esc cancel',
      fuzzy_description = 'Find project  › ',
      fuzzy = true, choices = choices,
      action = wezterm.action_callback(function(inner_window, inner_pane, id)
        if id and by_id[id] then M.open(inner_window, inner_pane, by_id[id]) end
      end),
    }, pane)
  end

  function M.label(workspace)
    local project = (wezterm.GLOBAL.dotfiles_projects or {})[workspace]
    return project and (project.repository .. ' / ' .. project.branch) or workspace
  end

  function M.cwd(window, pane)
    local uri = pane:get_current_working_dir()
    if uri and uri.file_path then return uri.file_path end
    local project = (wezterm.GLOBAL.dotfiles_projects or {})[window:active_workspace()]
    return project and project.path or wezterm.home_dir
  end

  function M.new_tab(window, pane)
    local tab = window:mux_window():spawn_tab { cwd = M.cwd(window, pane), args = { options.shell, '-NoLogo' } }
    tab:activate()
  end

  function M.split(direction)
    return wezterm.action_callback(function(window, pane)
      pane:split { direction = direction, cwd = M.cwd(window, pane), args = { options.shell, '-NoLogo' } }
    end)
  end
end

return M
