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
fake.action = setmetatable({}, { __index = function(_, name)
  return function(value) return { kind = name, value = value } end
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
  return { set_title = function() end }, editor, {}
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
assert(#selected.choices == 3, 'Disk projects and live default workspace must share one picker')
selected.action(window, original, nil)
assert(#spawned == 0 and current == 'default', 'Cancel must leave the running application unchanged')
selected.action(window, original, a.workspace)
assert(#spawned == 1 and #splits == 2, 'First visit must create one three-pane workspace')
assert(spawned[1].cwd == a.path and splits[1].cwd == a.path and splits[2].cwd == a.path, 'Every pane must start in the exact selected path')
assert(spawned[1].editor.activated, 'Focus must return to the editor')
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
os.remove(cache_file)
vim.fn.delete(options.cache_dir, 'd')
print('PASS: workspace reuse, process preservation, cancellation, background index and cwd inheritance.')
