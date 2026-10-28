local wezterm = require 'wezterm'
local M = {}

local function label(row)
  local parts = {}
  for modifier in row.mods:gmatch('[^|]+') do
    if modifier ~= 'NONE' and modifier ~= 'LEADER' then
      -- '?' is already the shifted character on the supported keyboard layout.
      if modifier ~= 'SHIFT' or row.key ~= '?' then
        parts[#parts + 1] = modifier == 'CTRL' and 'Ctrl' or (modifier == 'SHIFT' and 'Shift' or modifier)
      end
    end
  end
  local key = row.key
  if #key == 1 and key:match('%u') then key = key:lower() end
  parts[#parts + 1] = key
  return (row.mods:find('LEADER', 1, true) and 'Prefix, ' or '') .. table.concat(parts, '+')
end

function M.new(actions)
  local api = { keys = {}, key_tables = { resize = {} }, mouse_bindings = {}, rows = {} }
  wezterm.add_to_config_reload_watch_list(wezterm.config_dir .. '/shortcuts.tsv')
  local handle = assert(io.open(wezterm.config_dir .. '/shortcuts.tsv', 'r'))
  for line in handle:lines() do
    if not line:match('^group\t') and line ~= '' then
      local group, scope, key, mods, action, description = line:gsub('\r$', ''):match('^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$')
      assert(group, 'Invalid shortcut row: ' .. line)
      local row = { group = group, scope = scope, key = key, mods = mods, action = action, description = description }
      row.label = label(row)
      api.rows[#api.rows + 1] = row
      assert(actions[action], 'Unknown shortcut action: ' .. action)
      if scope == 'mouse' then
        api.mouse_bindings[#api.mouse_bindings + 1] = { event = { Down = { streak = 1, button = 'Left' } }, mods = mods, action = actions[action] }
      elseif key == '1..9' then
        for number = 1, 9 do api.keys[#api.keys + 1] = { key = tostring(number), mods = mods, action = actions[action](number) } end
      else
        local target = scope == 'resize' and api.key_tables.resize or api.keys
        target[#target + 1] = { key = key, mods = mods, action = actions[action] }
      end
    end
  end
  handle:close()

  function api.help(window, pane)
    local choices, previous = {}, nil
    for i, row in ipairs(api.rows) do
      if row.group ~= previous then
        choices[#choices + 1] = { id = 'group:' .. i, label = wezterm.format {
          { Foreground = { Color = '#82b7e8' } }, { Attribute = { Intensity = 'Bold' } }, { Text = row.group:upper() },
        } }
        previous = row.group
      end
      choices[#choices + 1] = { id = tostring(i), label = string.format('  %-24s %s', row.label, row.description) }
    end
    window:perform_action(wezterm.action.InputSelector {
      title = 'Keyboard shortcuts — Prefix: Ctrl+a, release, then key',
      description = 'Read-only help · Enter/Esc close',
      fuzzy_description = 'Find shortcut › ', fuzzy = true, choices = choices,
      action = wezterm.action_callback(function() end),
    }, pane)
  end
  return api
end

return M
