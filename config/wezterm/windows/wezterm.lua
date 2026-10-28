local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()
package.path = wezterm.config_dir .. '/?.lua;' .. package.path

local options = {
  project_roots = { (os.getenv('USERPROFILE') or wezterm.home_dir) .. '/Code' },
  max_depth = 4,
  cache_seconds = 30,
  shell = 'pwsh.exe',
  editor = 'nvim.exe',
  agent = 'copilot.exe',
  font = 'JetBrainsMonoNL Nerd Font Mono',
  font_size = 12.0,
  opacity = 0.94,
}
-- Local preferences apply until the next explicit configuration replacement.
local local_file = wezterm.config_dir .. '/local.lua'
wezterm.add_to_config_reload_watch_list(local_file)
local local_handle = io.open(local_file, 'r')
if local_handle then
  local_handle:close()
  for key, value in pairs(dofile(local_file)) do options[key] = value end
end

local projects = require 'projects'
projects.setup(options)
local colors = {
  background = '#1d2129', foreground = '#c9d1df', muted = '#687386',
  blue = '#82b7e8', purple = '#b39ddb', green = '#a4be8c',
}
config.default_prog = { options.shell, '-NoLogo' }
config.default_cwd = wezterm.home_dir
config.font = wezterm.font_with_fallback { options.font, 'JetBrainsMono Nerd Font Mono', 'JetBrains Mono' }
config.font_size = options.font_size
config.line_height = 1.08
config.window_decorations = 'NONE'
config.window_background_opacity = options.opacity
config.win32_system_backdrop = options.opacity < 1.0 and 'Acrylic' or 'Disable'
config.text_background_opacity = 1.0
config.window_padding = { left = 14, right = 14, top = 12, bottom = 10 }
config.initial_cols = 150
config.initial_rows = 42
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 32
config.enable_scroll_bar = false
config.scrollback_lines = 10000
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 650
config.audible_bell = 'Disabled'
config.window_close_confirmation = 'AlwaysPrompt'
config.exit_behavior = 'CloseOnCleanExit'
config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.88 }
config.command_palette_bg_color = '#252b36'
config.command_palette_fg_color = colors.foreground
config.command_palette_font_size = 12
config.command_palette_rows = 14
config.colors = {
  foreground = colors.foreground, background = colors.background,
  cursor_bg = colors.blue, cursor_fg = colors.background, cursor_border = colors.blue,
  selection_bg = '#3c4760', selection_fg = '#eef2f8', split = '#303744',
  ansi = { '#222731', '#e88c9a', '#a4be8c', '#dfbd83', '#82b7e8', '#b39ddb', '#87c7cb', '#c9d1df' },
  brights = { '#687386', '#f2a3af', '#b7cf9c', '#eed29c', '#a0ccf3', '#cbb5ef', '#a1dadd', '#eef2f8' },
  tab_bar = {
    background = '#181c23',
    active_tab = { bg_color = '#30394a', fg_color = '#dfe8f5', intensity = 'Bold' },
    inactive_tab = { bg_color = '#181c23', fg_color = colors.muted },
    inactive_tab_hover = { bg_color = '#252b36', fg_color = colors.foreground },
  },
}

local function picker(refresh, running_only)
  return wezterm.action_callback(function(window, pane) projects.pick(window, pane, refresh, running_only) end)
end
local function toggle_opaque(window)
  local overrides = window:get_config_overrides() or {}
  if window:effective_config().window_background_opacity < 1.0 then
    overrides.window_background_opacity = 1.0
    overrides.win32_system_backdrop = 'Disable'
  else
    overrides.window_background_opacity = options.opacity < 1.0 and options.opacity or 0.94
    overrides.win32_system_backdrop = 'Acrylic'
  end
  window:set_config_overrides(overrides)
end

config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1500 }
local bindings
local actions = {
  projects_all = picker(false, false),
  projects_refresh = picker(true, false),
  projects_active = picker(false, true),
  project_close = wezterm.action_callback(projects.close),
  pane_left = act.ActivatePaneDirection 'Left',
  pane_down = act.ActivatePaneDirection 'Down',
  pane_up = act.ActivatePaneDirection 'Up',
  pane_right = act.ActivatePaneDirection 'Right',
  split_right = projects.split 'Right', split_below = projects.split 'Bottom',
  pane_select = act.PaneSelect { alphabet = '123456789' },
  pane_swap = act.PaneSelect { mode = 'SwapWithActive', alphabet = '123456789' },
  pane_zoom = act.TogglePaneZoomState,
  pane_close = act.CloseCurrentPane { confirm = true },
  resize_mode = act.ActivateKeyTable { name = 'resize', one_shot = false },
  tab_new = wezterm.action_callback(projects.new_tab),
  tab_next = act.ActivateTabRelative(1), tab_previous = act.ActivateTabRelative(-1),
  tab_number = function(number) return act.ActivateTab(number - 1) end,
  tab_left = act.MoveTabRelative(-1), tab_right = act.MoveTabRelative(1),
  tab_rename = act.PromptInputLine {
    description = 'Tab name', action = wezterm.action_callback(function(window, _, title)
      if title and title ~= '' then window:active_tab():set_title(title) end
    end),
  },
  help = wezterm.action_callback(function(window, pane) bindings.help(window, pane) end),
  quit = act.QuitApplication, reload = act.ReloadConfiguration,
  copy = act.ActivateCopyMode, literal_prefix = act.SendKey { key = 'a', mods = 'CTRL' },
  opacity = wezterm.action_callback(toggle_opaque),
  maximize = wezterm.action_callback(function(window) window:maximize() end),
  fullscreen = act.ToggleFullScreen, palette = act.ActivateCommandPalette,
  drag = act.StartWindowDrag,
  resize_left = act.AdjustPaneSize { 'Left', 3 }, resize_down = act.AdjustPaneSize { 'Down', 3 },
  resize_up = act.AdjustPaneSize { 'Up', 3 }, resize_right = act.AdjustPaneSize { 'Right', 3 },
  resize_exit = act.PopKeyTable,
}
bindings = require('bindings').new(actions)
config.keys = bindings.keys
config.key_tables = bindings.key_tables
config.mouse_bindings = bindings.mouse_bindings

wezterm.on('format-window-title', function(tab)
  local window = wezterm.mux.get_window(tab.window_id)
  return projects.label(window and window:get_workspace() or 'default') .. ' — WezTerm'
end)
wezterm.on('format-tab-title', function(tab)
  local window = wezterm.mux.get_window(tab.window_id)
  local title = tab.tab_title
  -- Normalize titles in already-running project tabs created by the older config.
  if title == '' or title == projects.label(window and window:get_workspace() or 'default') then
    title = title == '' and tab.active_pane.title or 'Project'
  end
  return ' ' .. (tab.tab_index + 1) .. '  ' .. title .. ' '
end)
wezterm.on('update-status', function(window)
  local mode = window:active_key_table() or (window:leader_is_active() and 'prefix' or '')
  window:set_left_status(wezterm.format {
    { Foreground = { Color = colors.blue } }, { Text = '  ' .. projects.label(window:active_workspace()) .. '  ' },
  })
  window:set_right_status(wezterm.format {
    { Foreground = { Color = colors.purple } }, { Text = mode ~= '' and ('  ' .. mode .. '  ') or '  ^a f projects  ' },
  })
end)
wezterm.on('augment-command-palette', function()
  return {
    { brief = 'Projects: open or return to a checkout', action = picker(false, false) },
    { brief = 'Projects: refresh project and worktree list', action = picker(true, false) },
    { brief = 'Projects: show active projects', action = picker(false, true) },
    { brief = 'Projects: close current project and all its tabs', action = wezterm.action_callback(projects.close) },
    { brief = 'WezTerm: quit all projects (one confirmation)', action = act.QuitApplication },
    { brief = 'Help: keyboard shortcuts', action = actions.help },
    { brief = 'Layout: toggle focus on the current pane', action = act.TogglePaneZoomState },
    { brief = 'Appearance: toggle opaque / acrylic', action = wezterm.action_callback(toggle_opaque) },
  }
end)

return config
