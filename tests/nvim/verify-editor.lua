-- Offline checks: real Neovim mappings/views, plugin declarations, and dashboard rendering.
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))))
local config = root .. '/config/nvim/common'
package.path = config .. '/lua/?.lua;' .. config .. '/lua/?/init.lua;' .. package.path
vim.opt.rtp:prepend(config)
for _, file in ipairs(vim.fn.glob(config .. '/**/*.lua', false, true)) do assert(loadfile(file)) end
require('settings').setup()
require('mappings').setup()
require('autocommands').setup()

for _, key in ipairs({ 'pp', 'pn', 'pd', 'ps', 'wb', 'ww', 'wn' }) do
  assert(vim.fn.maparg(' ' .. key, 'n') == '', 'Removed manager binding remains: ' .. key)
end
for _, command in ipairs({ 'Projects', 'ProjectOpen', 'ProjectNew', 'ProjectSave', 'ProjectClose', 'Worktree', 'WorktreeNew', 'WorktreeSwitch' }) do
  assert(vim.fn.exists(':' .. command) == 0, 'Removed manager command remains: ' .. command)
end
assert(not vim.uv.fs_stat(config .. '/projects.nvim/lua/projects/init.lua'))
assert(not vim.uv.fs_stat(config .. '/worktree.nvim/lua/worktree/init.lua'))

local specs, shortcuts = {}, {}
local function collect(spec)
  if type(spec[1]) == 'string' then
    specs[spec[1]] = spec
    for _, mapping in ipairs(spec.keys or {}) do
      if mapping.desc then shortcuts[mapping[1]:gsub('<leader>', ' ')] = mapping.desc end
    end
  else for _, child in ipairs(spec) do collect(child) end end
end
for _, file in ipairs(vim.fn.glob(config .. '/lua/plugins/*.lua', false, true)) do collect(dofile(file)) end
for _, mapping in ipairs(vim.api.nvim_get_keymap('n')) do
  if mapping.desc then shortcuts[mapping.lhs] = mapping.desc end
end
assert(not specs['projects.nvim'] and not specs['worktree.nvim'], 'Removed local plugins must not be declared')
assert(specs['esmuellert/codediff.nvim'] and specs['CopilotC-Nvim/CopilotChat.nvim'], 'IDE review/chat tools must remain')
assert(not shortcuts[' gb'], 'Branch checkout must stay outside the editor')
assert(shortcuts[' ff'] and shortcuts[' rt'] and shortcuts[' gc'], 'File search, tests and diff review must remain')
local snacks = specs['folke/snacks.nvim']
for _, entry in ipairs(snacks.opts.dashboard.preset.keys) do assert(entry.key ~= 'p', 'Dashboard still offers project management') end
assert(#require('dashboard').header() > 0 and not require('dashboard').projects, 'Dashboard must render without the project manager')
for _, entry in ipairs(specs['folke/which-key.nvim'].opts.spec) do
  assert(entry[1] ~= '<leader>p' and entry[1] ~= '<leader>w', 'Removed shortcut group remains')
end

-- Execute the actual view mappings with an unsaved buffer in the inherited directory.
local original_cwd = vim.fn.getcwd()
local buffer = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(buffer, original_cwd .. '/editor-check.txt')
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { 'unsaved editor content' })
local function invoke(key)
  local mapping = vim.fn.maparg(key, 'n', false, true)
  if mapping.callback then mapping.callback()
  else vim.cmd(assert(mapping.rhs:match('^<cmd>(.-)<cr>$'))) end
end
invoke(' <Tab>n')
assert(#vim.api.nvim_list_tabpages() == 2 and vim.fn.getcwd() == original_cwd, 'New views must retain the inherited directory')
assert(vim.t.project_root == nil, 'Views must not acquire project-manager state')
invoke(' <Tab>x')
assert(#vim.api.nvim_list_tabpages() == 1 and vim.bo[buffer].modified, 'Closing a view must preserve unsaved editor buffers')
local render = specs['nanozuki/tabby.nvim'].opts.line
local tab = vim.api.nvim_get_current_tabpage()
local line = {
  tabs = function() return { foreach = function(callback)
    return callback({ id = tab, number = function() return 1 end, is_current = function() return true end })
  end } end,
  spacer = function() return '' end,
}
assert(render(line)[2][2] == 'editor-check.txt', 'View tabs must show filenames rather than project names')
vim.t.tab_name = 'Review'
assert(render(line)[2][2] == 'Review', 'Custom view names must still work')
assert(vim.fn.getcwd() == original_cwd and not package.loaded.projects and not package.loaded.worktree, 'Editor startup must not load a manager or change directory')
if vim.env.DOTFILES_SHORTCUT_EXPORT then
  vim.fn.writefile({ vim.json.encode(shortcuts) }, vim.env.DOTFILES_SHORTCUT_EXPORT)
end
vim.bo[buffer].modified = false
print('PASS: editor-only startup, inherited cwd, ordinary view tabs, unsaved buffers, dashboard and retained IDE bindings.')
