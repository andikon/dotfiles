-- A slow discovery worker must never delay showing the actual project picker.
local config_dir = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))) .. '/config/wezterm/windows'
package.path = config_dir .. '/?.lua;' .. package.path
local selected, scans, background = nil, 0, 0
local fixture = { workspace = 'project:fixture', path = 'C:/Code/fixture', repository = 'fixture', branch = 'main' }
local fake = {
  config_dir = config_dir, home_dir = 'C:/Users/test', GLOBAL = {},
  json_encode = vim.json.encode, json_parse = vim.json.decode,
  action_callback = function(callback) return callback end,
  log_warn = function() end,
  format = function(parts)
    local text = {}
    for _, part in ipairs(parts) do if part.Text then text[#text + 1] = part.Text end end
    return table.concat(text)
  end,
  mux = { get_workspace_names = function() return { 'default' } end },
  run_child_process = function()
    scans = scans + 1
    vim.wait(350)
    return true, vim.json.encode { projects = { fixture }, warnings = {} }, ''
  end,
  background_child_process = function() background = background + 1 end,
  time = { call_after = function() end },
  on = function() end,
}
fake.action = setmetatable({}, { __index = function(_, name)
  return function(value) return { kind = name, value = value } end
end })
local window = {
  active_workspace = function() return 'default' end,
  toast_notification = function() end,
  perform_action = function(_, action) if action.kind == 'InputSelector' then selected = action.value end end,
}
package.loaded.wezterm = fake
local projects = dofile(config_dir .. '/projects.lua')
local options = { shell = 'pwsh.exe', editor = 'nvim.exe', agent = 'copilot.exe', project_roots = { 'C:/Code' }, max_depth = 4, cache_seconds = 30, cache_dir = vim.fn.tempname() }

local failures = {}
for _, scenario in ipairs { 'cold', 'expired', 'refresh' } do
  local file, signature = require('project-index').location(options)
  if scenario ~= 'cold' then
    vim.fn.mkdir(options.cache_dir, 'p')
    vim.fn.writefile({ vim.json.encode { signature = signature, time = os.time() - 60, projects = { fixture } } }, file)
  end
  projects.setup(options)
  selected = nil
  local start = vim.uv.hrtime()
  projects.pick(window, {}, scenario == 'refresh', false)
  local elapsed = (vim.uv.hrtime() - start) / 1e6
  print(string.format('%s picker: %.2f ms', scenario, elapsed))
  if not selected or elapsed >= 25 then failures[#failures + 1] = scenario .. ' picker waited for discovery' end
end
if scans > 0 then failures[#failures + 1] = 'picker called the synchronous scanner ' .. scans .. ' times' end
assert(#failures == 0, table.concat(failures, '; '))
assert(background == 0, 'Even process creation must be deferred until after the picker opens')
local file = require('project-index').location(options)
os.remove(file)
vim.fn.delete(options.cache_dir, 'd')
print('PASS: cold, expired-cache and refresh menus open without waiting for discovery.')
