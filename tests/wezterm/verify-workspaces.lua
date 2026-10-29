-- Run with nvim --headless -u NONE -l this-file.lua; no editor plugins are loaded.
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))) .. '/config/wezterm/windows'
package.path = root .. '/?.lua;' .. package.path
local live, spawned, splits, scans = { default = true }, {}, {}, 0
local current, selected, notices = 'default', nil, {}
local timers, cache_file, signature, worker_error = {}, nil, nil, false
local fake = {
  config_dir = root, home_dir = 'C:/Users/test', GLOBAL = {},
  json_encode = vim.json.encode, json_parse = vim.json.decode,
  action_callback = function(callback) return callback end,
  log_warn = function() end,
  format = function(parts)
    local text = {}
    for _, part in ipairs(parts) do if part.Text then text[#text + 1] = part.Text end end
    return table.concat(text)
  end,
  mux = {},
  on = function() end,
  time = { call_after = function(_, callback) timers[#timers + 1] = callback end },
}
fake.action = setmetatable({}, { __index = function(actions, name)
  local constructor = function(value) return { kind = name, value = value } end
  rawset(actions, name, constructor)
  return constructor
end })
local function new_pane(args)
  return {
    args = args,
    activate = function(self) self.activated = true end,
    split = function(_, spec)
      splits[#splits + 1] = spec
      return new_pane(spec.args)
    end,
  }
end
fake.mux.get_workspace_names = function()
  local names = {}
  for name in pairs(live) do names[#names + 1] = name end
  return names
end
fake.mux.spawn_window = function(spec)
  spawned[#spawned + 1] = spec
  live[spec.workspace] = true
  local editor = new_pane(spec.args)
  spec.editor = editor
  return { set_title = function(_, title) spec.title = title end }, editor, {}
end
local a = { workspace = 'project:a', path = "C:/Code/team's worktree Ü & one", repository = 'shared', branch = 'main' }
local b = { workspace = 'project:b', path = 'D:/Other/shared', repository = 'shared', branch = 'feature' }
fake.run_child_process = function()
  error('The picker must never run a foreground discovery process')
end
fake.background_child_process = function()
  scans = scans + 1
  vim.fn.writefile({ vim.json.encode {
    signature = signature, time = os.time(), generation = scans, projects = { a, b },
    error = worker_error and 'fixture failure' or '',
  } }, cache_file)
end
local window = {
  active_workspace = function() return current end,
  toast_notification = function(_, _, message) notices[#notices + 1] = message end,
  perform_action = function(_, action)
    if action.kind == 'InputSelector' then selected = action.value end
    if action.kind == 'SwitchToWorkspace' then current = action.value.name end
  end,
}
local original = { get_current_working_dir = function() return nil end }
package.loaded.wezterm = fake
local projects = dofile(root .. '/projects.lua')
local options = { shell = 'pwsh.exe', editor = 'nvim.exe', agent = 'copilot.exe', project_roots = { 'C:/Code' }, max_depth = 4, cache_seconds = 30, cache_dir = vim.fn.tempname() }
cache_file, signature = require('project-index').location(options)
vim.fn.mkdir(options.cache_dir, 'p')
vim.fn.writefile({ vim.json.encode { signature = signature, time = os.time() - 60, projects = { a, b } } }, cache_file)
projects.setup(options)
local function flush_timers()
  while #timers > 0 do table.remove(timers, 1)() end
end

projects.pick(window, original, false, false)
assert(scans == 0, 'The picker must open before a worker is started')
assert(#selected.choices == 3 and selected.choices[1].id == b.workspace and selected.choices[2].id == a.workspace, 'All projects must include sorted checkouts and a view switch, excluding the home shell')
assert(selected.choices[3].id == '__view__' and selected.title == 'Projects — All projects', 'All projects must offer the active view')
selected.action(window, original, '__view__')
assert(selected.title == 'Projects — Active projects' and selected.choices[1].id == '__empty__', 'An empty active view must stay usable without listing unopened projects or the home shell')
assert(scans == 0, 'Switching views must not block on discovery')
selected.action(window, original, '__view__')
selected.action(window, original, nil)
assert(#spawned == 0 and current == 'default', 'Cancel must leave the running application unchanged')
selected.action(window, original, a.workspace)
assert(#spawned == 1 and #splits == 2, 'First visit must create one three-pane workspace')
assert(spawned[1].cwd == a.path and splits[1].cwd == a.path and splits[2].cwd == a.path, 'Every pane must start in the exact selected path')
assert(spawned[1].editor.activated, 'Focus must return to the editor')
assert(spawned[1].title ~= projects.label(a.workspace), 'The tab must not repeat the project label already shown in the header')
assert(splits[1].args[#splits[1].args] == 'copilot.exe', 'Agent pane must launch the configured CLI')
spawned[1].editor.unsaved_work = 'keep this state'
projects.open(window, original, b)
projects.open(window, original, a)
assert(#spawned == 2 and #splits == 4 and current == a.workspace, 'Return visits must reuse the original workspace')
assert(spawned[1].editor.unsaved_work == 'keep this state', 'Returning must preserve the original process/pane')

projects.pick(window, original, false, false)
local open_menu = selected
flush_timers()
assert(scans == 1, 'Repeated picks should reuse the disk cache')
assert(selected == open_menu, 'Background completion must not replace the menu or interrupt typed input')
assert(selected.choices[1].id == a.workspace, 'Current workspace should sort first')
local before = scans
projects.pick(window, original, false, true)
assert(scans == before and #selected.choices == 3, 'Running-only picker must use live state without scanning')
assert(selected.choices[1].id == a.workspace and selected.choices[2].id == b.workspace, 'Active projects must include all open checkouts')
live[b.workspace] = nil
projects.pick(window, original, false, true)
assert(#selected.choices == 2 and selected.choices[1].id == a.workspace, 'Closed checkouts must disappear from the active view immediately')
live[b.workspace] = true
projects.pick(window, original, true, false)
flush_timers()
assert(scans == before + 1, 'Refresh must bypass the disk cache')

local tab_activated = false
window.mux_window = function() return { spawn_tab = function(_, spec)
  assert(spec.cwd == a.path, 'New tabs must fall back to their workspace root')
  return { activate = function() tab_activated = true end }
end } end
projects.new_tab(window, original)
assert(tab_activated, 'The new tab must become active')
assert(projects.cwd(window, { get_current_working_dir = function() return { file_path = 'C:/Code/a/subfolder' } end }) == 'C:/Code/a/subfolder', 'Reported shell cwd must take precedence')

worker_error = true
projects.pick(window, original, true, false)
flush_timers()
assert(#notices == 1 and #selected.choices == 3, 'Scan failure must keep cached projects and running workspaces usable')
live[a.workspace] = nil
projects.open(window, original, a)
assert(#spawned == 3, 'Reopening a closed workspace must create a fresh one')
-- A new Lua context/process can immediately use the persisted catalog.
fake.GLOBAL = {}
projects.setup(options)
projects.pick(window, original, false, false)
assert(#selected.choices == 3 and #timers == 0, 'Persisted projects must be available immediately after reload')
-- Model native Multiple dispatch: actions complete before GUI reconciliation.
local windows, closed, dispatches = {}, {}, 0
local function fixture_window(id, workspace, count)
  local tabs, active = {}, 1
  for i = 1, count do tabs[i] = workspace .. ':' .. id .. ':' .. i end
  local gui = {
    window_id = function() return id end,
    active_workspace = function() return current end,
    toast_notification = window.toast_notification,
    perform_action = function(_, action)
      if action.kind == 'InputSelector' then selected = action.value; return end
      assert(action.kind == 'Multiple', 'Close must use one native batch per window')
      dispatches = dispatches + 1
      for _, item in ipairs(action.value) do
        if item.kind == 'ActivateTab' then active = item.value + 1
        elseif item.kind == 'CloseCurrentTab' then
          assert(item.value.confirm == false, 'Confirmation must not repeat per tab or pane')
          closed[#closed + 1] = table.remove(tabs, active)
        elseif item.kind == 'SwitchToWorkspace' then current = item.value.name
        else error('Unexpected close action: ' .. item.kind) end
      end
    end,
  }
  local mux = {
    get_workspace = function() return workspace end,
    window_id = function() return id end,
    tabs = function() return tabs end,
    gui_window = function() return gui end,
  }
  windows[#windows + 1] = mux
  return gui, mux
end
fake.mux.all_windows = function() return windows end
current = a.workspace
local caller = fixture_window(12, a.workspace, 2)
fixture_window(13, a.workspace, 1)
local _, other = fixture_window(14, b.workspace, 2)
projects.close(caller, original)
assert(selected.choices[1].id == 'cancel', 'The safe choice must be selected by default')
selected.action(caller, original, nil)
selected.action(caller, original, 'cancel')
assert(#closed == 0 and current == a.workspace, 'Cancel must preserve all tabs and focus')
selected.action(caller, original, 'close')
assert(#closed == 3 and dispatches == 2, 'Close must include all tabs in all project windows')
assert(#other:tabs() == 2 and current == b.workspace, 'Another project must stay untouched and become active')
windows, closed, dispatches = {}, {}, 0
current = a.workspace
caller = fixture_window(15, a.workspace, 3)
local spawn_before = #spawned
projects.close(caller, original)
selected.action(caller, original, 'close')
assert(#closed == 3 and #spawned == spawn_before + 1 and current == 'default', 'Closing the last project must leave a fresh home shell')
assert(spawned[#spawned].cwd == fake.home_dir and spawned[#spawned].args[1] == options.shell, 'The home shell must use the configured shell')
windows, closed = {}, {}
current = a.workspace
caller = fixture_window(16, a.workspace, 1)
projects.close(caller, original)
current = b.workspace
selected.action(caller, original, 'close')
assert(#closed == 0, 'An outdated confirmation must not close a different active project')

local events = {}
fake.on = function(name, callback) events[name] = callback end
fake.config_builder = function() return {} end
fake.font_with_fallback = function(fonts) return fonts end
fake.add_to_config_reload_watch_list = function() end
fake.mux.get_window = function() return { get_workspace = function() return a.workspace end } end
package.loaded.projects = projects
local config = dofile(root .. '/wezterm.lua')
assert(config.enable_tab_bar and not config.hide_tab_bar_if_only_one_tab, 'The header must always be shown')
local quit_bound, close_bound = false, false
local help_action
for _, key in ipairs(config.keys) do
  assert(not (key.key == 'b' and key.mods == 'LEADER'), 'The header toggle must not remain bound')
  if key.key == 'Q' and key.mods == 'LEADER|SHIFT' then quit_bound = key.action == fake.action.QuitApplication end
  if key.key == 'X' and key.mods == 'LEADER|SHIFT' then close_bound = type(key.action) == 'function' end
  if key.key == '?' then help_action = key.action end
end
assert(quit_bound and close_bound, 'Project close and native application quit must be bound')
assert(type(help_action) == 'function', 'Ctrl+a ? must open help')
local help_window = { perform_action = function(_, action) selected = action.value end }
help_action(help_window, original)
assert(selected.fuzzy and selected.title:find('Ctrl+a', 1, true), 'Shortcut help must be searchable and explain the prefix')
local help_rows = selected.choices
local found_quit, found_resize = false, false
for _, row in ipairs(help_rows) do
  if row.label:find('Quit WezTerm', 1, true) then found_quit = row.label:find('Shift+q', 1, true) ~= nil end
  if row.label:find('Resize left', 1, true) then found_resize = true end
end
assert(found_quit and found_resize, 'Help must reflect registry bindings and resize mode')
local before_help = #closed
selected.action(help_window, original, nil)
selected.action(help_window, original, '25')
assert(#closed == before_help, 'Help must never dispatch destructive actions')
local tab = { tab_title = projects.label(a.workspace), tab_index = 0, window_id = 12, active_pane = { title = 'pwsh' } }
assert(events['format-tab-title'](tab) == ' 1  Project ', 'Existing tabs must stop repeating the header after reload')
tab.tab_title = 'My notes'
assert(events['format-tab-title'](tab) == ' 1  My notes ', 'Custom tab names must be preserved')
tab.tab_title = ''
assert(events['format-tab-title'](tab) == ' 1  pwsh ', 'Shell tabs must use the active process title')
assert(config.window_close_confirmation == 'AlwaysPrompt', 'Native quit must retain its application-wide confirmation')
assert(config.window_background_opacity == 0 and config.win32_system_backdrop == 'Acrylic', 'Default appearance must use full Windows Acrylic')
assert(config.text_background_opacity == 1, 'Colored text backgrounds must remain readable')
local opacity_action
for _, binding in ipairs(config.keys) do
  if binding.key == 'o' and binding.mods == 'LEADER' then opacity_action = binding.action end
end
local overrides = { font_size = 15 }
local appearance_window = {
  get_config_overrides = function() return overrides end,
  effective_config = function() return { window_background_opacity = overrides.window_background_opacity or config.window_background_opacity } end,
  set_config_overrides = function(_, value) overrides = value end,
}
opacity_action(appearance_window)
assert(overrides.window_background_opacity == 1 and overrides.win32_system_backdrop == 'Disable', 'Toggle must switch Acrylic to a solid background')
opacity_action(appearance_window)
assert(overrides.window_background_opacity == 0 and overrides.win32_system_backdrop == 'Acrylic', 'Second toggle must restore full Acrylic, not the old almost-opaque tint')
assert(overrides.font_size == 15, 'Appearance toggle must preserve unrelated window overrides')
local clock = 'Thursday, 29 October 2026 14:37'
fake.strftime = function(format)
  assert(format == '%A, %d %B %Y %H:%M', 'Clock must show weekday, date and local time')
  return clock
end
local right_status, left_status, key_table
local status_window = {
  active_key_table = function() return key_table end,
  active_workspace = function() return a.workspace end,
  set_left_status = function(_, text) left_status = text end,
  set_right_status = function(_, text) right_status = text end,
}
events['update-status'](status_window)
assert(left_status:find(projects.label(a.workspace), 1, true), 'Header must retain project identity')
assert(right_status:find(clock, 1, true) and not right_status:find('^a', 1, true) and not right_status:find('help', 1, true), 'Header must show the clock without shortcut hints')
clock = 'Thursday, 29 October 2026 14:38'
key_table = 'resize'
events['update-status'](status_window)
assert(right_status:find(clock, 1, true) and right_status:find('RESIZE', 1, true), 'Clock must keep updating while resize mode is active')
os.remove(cache_file)
vim.fn.delete(options.cache_dir, 'd')
print('PASS: workspace reuse, process preservation, cancellation, background index, cwd inheritance, project closure, Acrylic toggle and header clock.')
