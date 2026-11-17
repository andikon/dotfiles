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
assert(vim.o.showtabline == 0 and not specs['nanozuki/tabby.nvim'], 'Editor views must work with the tabline hidden')
local lualine
package.loaded.lualine = { setup = function(options) lualine = options end }
specs['nvim-lualine/lualine.nvim'].config()
package.loaded.lualine = nil
local tab_label = lualine.sections.lualine_b[1][1]
assert(tab_label() == '', 'Unnamed views must leave the statusline label empty')
local original_input = vim.ui.input
vim.ui.input = function(_, callback) callback('Review 100%') end
invoke(' <Tab>r')
vim.ui.input = original_input
assert(vim.api.nvim_eval_statusline(tab_label(), {}).str == 'Review 100%', 'Named views must appear in the statusline')
invoke(' <Tab>x')
assert(#vim.api.nvim_list_tabpages() == 1 and vim.bo[buffer].modified, 'Closing a view must preserve unsaved editor buffers')
assert(vim.fn.getcwd() == original_cwd and not package.loaded.projects and not package.loaded.worktree, 'Editor startup must not load a manager or change directory')
if vim.env.DOTFILES_SHORTCUT_EXPORT then
  vim.fn.writefile({ vim.json.encode(shortcuts) }, vim.env.DOTFILES_SHORTCUT_EXPORT)
end
vim.bo[buffer].modified = false
print('PASS: editor-only startup, inherited cwd, ordinary view tabs, unsaved buffers, dashboard and retained IDE bindings.')

local java = assert(specs['mfussenegger/nvim-jdtls'])
local mason = specs['mason-org/mason-lspconfig.nvim'].opts
assert(java.ft == 'java' and not specs['JetBrains/intellij-lsp.nvim'])
assert(vim.tbl_contains(mason.ensure_installed, 'jdtls') and vim.tbl_contains(mason.automatic_enable.exclude, 'jdtls'))
assert(vim.fn.maparg(' jl', 'n') == '', 'The old licensing shortcut must be removed')

local fixture = vim.fn.tempname() .. ' Java'
local function write(relative_path, lines)
  local path = vim.fs.joinpath(fixture, relative_path)
  vim.fn.mkdir(vim.fs.dirname(path), 'p')
  assert(vim.fn.writefile(lines or {}, path) == 0)
  return path
end
local original_env = {
  PATH = vim.env.PATH or false,
  XDG_DATA_HOME = vim.env.XDG_DATA_HOME or false,
  JDTLS_JAVA_HOME = vim.env.JDTLS_JAVA_HOME or false,
  JDTLS_JVM_ARGS = vim.env.JDTLS_JVM_ARGS or false,
}
local ok, failure = xpcall(function()
  local win = vim.fn.has('win32') == 1
  local launcher = write(win and 'bin/jdtls.cmd' or 'bin/jdtls', win and { '@echo off' } or { '#!/bin/sh' })
  if not win then assert(vim.uv.fs_chmod(launcher, 493)) end
  vim.env.PATH = vim.fs.dirname(launcher)
  vim.env.XDG_DATA_HOME = vim.fs.joinpath(fixture, 'editor-data')
  vim.env.JDTLS_JAVA_HOME = vim.fs.joinpath(fixture, 'test jdk')
  vim.env.JDTLS_JVM_ARGS = '-Xmx4g'
  package.loaded['mason.settings'] = { current = { install_root_dir = fixture } }
  package.loaded['blink.cmp'] = { get_lsp_capabilities = vim.lsp.protocol.make_client_capabilities }
  local starts = {}
  package.loaded.jdtls = {
    organize_imports = function() end,
    start_or_attach = function(options, _, start_options)
      assert(vim.api.nvim_get_current_buf() == start_options.bufnr)
      starts[#starts + 1] = options
    end,
  }
  java.config()

  write('pom.xml') -- An enclosing project must not absorb a nested Git checkout.
  write('one/reactor/.git')
  write('one/reactor/pom.xml')
  write('one/reactor/api/pom.xml')
  write('one/reactor/service/pom.xml')
  local source_a = write('one/reactor/api/src/com/example/Main.java')
  local source_b = write('one/reactor/service/src/Service.java')
  write('two/reactor/.git')
  write('two/reactor/mvnw.cmd')
  write('two/reactor/module/pom.xml')
  local source_c = write('two/reactor/module/src/Other.java')

  local function filetype(path, ft)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, path)
    vim.bo[buf].filetype = ft
    return buf
  end
  filetype(write('one/reactor/README.md'), 'markdown')
  assert(#starts == 0, 'Editor buffers must not start JDT LS before a Java file is opened')
  local source_buf = filetype(source_a, 'java')
  vim.api.nvim_set_current_dir(vim.fs.dirname(source_b))
  filetype(source_b, 'java')
  filetype(source_c, 'java')
  assert(#starts == 3)
  local first, second, third = unpack(starts)
  assert(first.root_dir == vim.fs.normalize(vim.uv.fs_realpath(fixture .. '/one/reactor')))
  assert(third.root_dir == vim.fs.normalize(vim.uv.fs_realpath(fixture .. '/two/reactor')))
  assert(first.cmd_cwd == first.root_dir and first.root_dir == second.root_dir)
  assert(vim.deep_equal(first.cmd, second.cmd), 'Modules must share the same persistent workspace regardless of cwd')
  assert(first.cmd[2] == '-data' and first.cmd[3] ~= third.cmd[3], 'Same-named checkouts must have separate workspaces')
  assert(first.cmd[3] == vim.fs.joinpath(vim.fn.stdpath('data'), 'jdtls', vim.fn.sha256(first.root_dir), 'workspace'))
  assert(vim.tbl_contains(first.cmd, '--jvm-arg=-Xmx4g'))
  assert(first.cmd[6] == '--java-executable' and first.cmd[7] ==
    vim.fs.joinpath(vim.env.JDTLS_JAVA_HOME, 'bin', win and 'java.exe' or 'java'))

  local new_path = fixture .. '/one/reactor/api/src/New.java'
  local new_buf = filetype(new_path, 'java')
  assert(#starts == 3 and not vim.uv.fs_stat(new_path), 'Opening a new Java buffer must not write a file')
  vim.bo[new_buf].undofile = false
  vim.api.nvim_buf_call(new_buf, function() vim.cmd('silent write') end)
  assert(#starts == 4 and vim.deep_equal(first.cmd, starts[4].cmd), 'Attach on the first explicit save')

  vim.cmd('filetype on')
  vim.api.nvim_set_current_buf(source_buf)
  local source_paths_key = 'org.eclipse.jdt.ls.core.sourcePaths'
  local requests = 0
  first.on_attach({
    server_capabilities = {},
    is_stopped = function() return false end,
    exec_cmd = function(_, command, context, callback)
      requests = requests + 1
      assert(context.bufnr == source_buf and command.command == 'java.project.getSettings')
      assert(vim.deep_equal(command.arguments, { vim.uri_from_bufnr(source_buf), { source_paths_key } }))
      callback(nil, { [source_paths_key] = { fixture .. '/one/reactor/api', fixture .. '/one/reactor/api/src' } })
    end,
  }, source_buf)
  local original_input, original_notify = vim.ui.input, vim.notify
  local input, warning
  vim.ui.input = function(_, callback) callback(input) end
  vim.notify = function(message) warning = message end
  invoke(' jn')
  assert(requests == 0, 'Canceling the Java file prompt must not make a request')
  input = '../Outside'
  invoke(' jn')
  assert(requests == 0 and warning:find('class name'), 'The prompt must accept class names only')
  input = 'Main'
  invoke(' jn')
  assert(vim.api.nvim_get_current_buf() == source_buf and warning:find('exists'), 'Existing files must be preserved')
  input = 'OrderService.java'
  invoke(' jn')
  local created = vim.api.nvim_get_current_buf()
  local expected = vim.fs.joinpath(vim.fs.dirname(source_a), 'OrderService.java')
  assert(vim.fs.normalize(vim.api.nvim_buf_get_name(created)) == vim.fs.normalize(expected))
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(created, 0, -1, false),
    { 'package com.example;', '', 'public class OrderService {', '', '}' }))
  assert(vim.bo[created].filetype == 'java', 'The new buffer must be recognized as Java')
  assert(vim.bo[created].modified and not vim.uv.fs_lstat(expected), 'The class should stay unsaved until written')
  vim.api.nvim_set_current_buf(source_buf)
  invoke(' jn')
  assert(vim.api.nvim_get_current_buf() == source_buf and warning:find('open'), 'Existing unsaved buffers must be preserved')
  vim.ui.input, vim.notify = original_input, original_notify
end, debug.traceback)
vim.api.nvim_set_current_dir(original_cwd)
for key, value in pairs(original_env) do vim.env[key] = value or nil end
vim.fn.delete(fixture, 'rf')
assert(ok, failure)
print('PASS: Java attachment, Maven roots, persistent workspaces, and source-aware new class templates.')
