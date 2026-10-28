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
  local known = wezterm.GLOBAL.dotfiles_projects or {}
  local notice_window
  local index = require('project-index').new(options, function(projects)
    for _, project in ipairs(projects) do known[project.workspace] = project end
    wezterm.GLOBAL.dotfiles_projects = known
  end, function(message)
    if notice_window then notify(notice_window, message) else wezterm.log_warn(message) end
  end)

  function M.warmup() index.request(false) end
  wezterm.on('gui-attached', M.warmup)
  wezterm.on('window-config-reloaded', M.warmup)

  local function pane_args(role)
    return {
      options.shell, '-NoLogo', '-NoExit', '-File', script_dir .. 'Start-Pane.ps1',
      '-Role', role, '-Program', role == 'editor' and options.editor or options.agent,
    }
  end

  function M.open(window, pane, project)
    if not known[project.workspace] then
      known[project.workspace] = project
      wezterm.GLOBAL.dotfiles_projects = known
    end
    if live_workspaces()[project.workspace] then
      window:perform_action(act.SwitchToWorkspace { name = project.workspace }, pane)
      return
    end
    local ok, err = pcall(function()
      local tab, editor = wezterm.mux.spawn_window {
        workspace = project.workspace, cwd = project.path, args = pane_args('editor'),
      }
      tab:set_title('Project')
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
    notice_window = window
    if not running_only then index.request(refresh) end
    -- Opening a picker never starts a shell, runs Git, or waits for discovery.
    local disk = running_only and {} or index.snapshot()
    local live = live_workspaces()
    local entries, seen = {}, {}
    for _, project in ipairs(disk) do
      entries[#entries + 1] = project
      seen[project.workspace] = true
    end
    for name in pairs(live) do
      if not seen[name] and known[name] then
        entries[#entries + 1] = known[name]
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
    if not running_only and #disk == 0 and index.pending() then
      choices[#choices + 1] = { id = '__indexing__', label = 'Indexing projects in the background…  Enter to check results' }
    end
    if #choices == 0 then
      choices[#choices + 1] = { id = '__empty__', label = running_only
        and 'No active projects. Choose Show all projects below.'
        or 'No projects found. Check project_roots in local.lua or refresh with Ctrl+a Shift+f.' }
    end
    choices[#choices + 1] = { id = '__view__', label = running_only and '→ Show all projects' or '→ Show active projects' }
    window:perform_action(act.InputSelector {
      title = running_only and 'Projects — Active projects' or 'Projects — All projects',
      description = 'Enter open · Esc cancel',
      fuzzy_description = 'Find project  › ',
      fuzzy = true, choices = choices,
      action = wezterm.action_callback(function(inner_window, inner_pane, id)
        if id == '__view__' then M.pick(inner_window, inner_pane, false, not running_only)
        elseif id == '__empty__' then M.pick(inner_window, inner_pane, false, running_only)
        elseif id == '__indexing__' then M.pick(inner_window, inner_pane, false, false)
        elseif id and by_id[id] then M.open(inner_window, inner_pane, by_id[id]) end
      end),
    }, pane)
  end

  function M.label(workspace)
    local project = known[workspace]
    return project and (project.repository .. ' / ' .. project.branch) or workspace
  end

  function M.close(window, pane)
    local workspace = window:active_workspace()
    window:perform_action(act.InputSelector {
      title = 'Close project: ' .. M.label(workspace),
      description = 'Ends every tab and process in this project. Save your work first.',
      choices = {
        { id = 'cancel', label = 'Keep project open' },
        { id = 'close', label = 'Close project and all its tabs' },
      },
      action = wezterm.action_callback(function(inner_window, inner_pane, id)
        if id ~= 'close' or inner_window:active_workspace() ~= workspace then return end
        local targets, remaining = {}, {}
        -- Resolve all GUI windows before doing anything destructive.
        for _, mux_window in ipairs(wezterm.mux.all_windows()) do
          if mux_window:get_workspace() == workspace then
            local gui = mux_window:gui_window()
            if not gui then notify(inner_window, 'Project window is unavailable; try again.'); return end
            targets[#targets + 1] = { gui = gui, tabs = #mux_window:tabs(), id = mux_window:window_id() }
          else
            remaining[mux_window:get_workspace()] = true
          end
        end
        if #targets == 0 then return end
        -- Keep the caller alive until the last action, then return to another workspace.
        table.sort(targets, function(a, b)
          if (a.id == inner_window:window_id()) ~= (b.id == inner_window:window_id()) then
            return b.id == inner_window:window_id()
          end
          return a.id < b.id
        end)
        local names = {}
        for name in pairs(remaining) do names[#names + 1] = name end
        table.sort(names)
        local destination = remaining.default and 'default' or names[1]
        if not destination then
          destination = workspace == 'default' and 'home' or 'default'
          wezterm.mux.spawn_window { workspace = destination, cwd = wezterm.home_dir, args = { options.shell, '-NoLogo' } }
        end
        for i, target in ipairs(targets) do
          local actions = {}
          for _ = 1, target.tabs do
            actions[#actions + 1] = act.ActivateTab(0)
            actions[#actions + 1] = act.CloseCurrentTab { confirm = false }
          end
          -- A single dispatch completes before workspace reconciliation closes the GUI.
          if i == #targets then actions[#actions + 1] = act.SwitchToWorkspace { name = destination } end
          target.gui:perform_action(act.Multiple(actions), inner_pane)
        end
      end),
    }, pane)
  end

  function M.cwd(window, pane)
    local uri = pane:get_current_working_dir()
    if uri and uri.file_path then return uri.file_path end
    local project = known[window:active_workspace()]
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
