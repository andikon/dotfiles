local wezterm = require 'wezterm'
local M = {}

-- Shared with Refresh-Projects.ps1 so the installer can prepare the first index.
function M.location(options)
  local roots = {}
  for _, root in ipairs(options.project_roots) do roots[#roots + 1] = root:gsub('\\', '/'):gsub('/+$', '') end
  local signature = 'projects-v2\n' .. options.max_depth .. '\n' .. table.concat(roots, '\n')
  local hash = 5381
  for i = 1, #signature do hash = (hash * 33 + signature:byte(i)) % 4294967296 end
  local directory = options.cache_dir or ((os.getenv('LOCALAPPDATA') or (wezterm.home_dir .. '/.cache')) .. '/wezterm/project-index')
  return directory .. '/projects-' .. string.format('%08x', hash) .. '.json', signature
end

function M.new(options, changed, failed)
  local file, signature = M.location(options)
  local state = { projects = {}, time = 0 }
  local contents, pending, started = nil, false, 0
  local api = {}

  local function load()
    local handle = io.open(file, 'r')
    if not handle then return false end
    local text = handle:read('*a')
    handle:close()
    if text == contents then return false end
    local ok, result = pcall(wezterm.json_parse, text)
    if not ok or type(result) ~= 'table' or result.signature ~= signature
        or type(result.projects) ~= 'table' or type(result.time) ~= 'number' then return false end
    contents, state = text, result
    if changed then changed(state.projects) end
    return true
  end

  -- Read once during config load. Opening a menu below only reads this Lua table.
  load()

  function api.snapshot() return state.projects end
  function api.pending() return pending end

  function api.request(force)
    if pending or (not force and os.time() - state.time < options.cache_seconds) then return end
    pending = true
    -- Give the overlay a frame before even creating the background process.
    wezterm.time.call_after(0.05, function()
      local previous = contents
      load() -- Another process may already have refreshed our shared on-disk index.
      if not force and os.time() - state.time < options.cache_seconds then pending = false; return end
      started = os.time()
      local ok, err = pcall(wezterm.background_child_process, {
        options.shell, '-NoLogo', '-NoProfile', '-NonInteractive', '-File',
        wezterm.config_dir .. '/scripts/Refresh-Projects.ps1',
        '-RootsJson', wezterm.json_encode(options.project_roots), '-MaxDepth', tostring(options.max_depth),
        '-CacheFile', file,
      })
      if not ok then pending = false; if failed then failed(tostring(err)) end; return end
      local function poll()
        if load() and contents ~= previous then
          pending = false
          if state.error and state.error ~= '' and failed then failed(state.error) end
          return
        end
        if os.time() - started >= 60 then
          pending = false
          -- Avoid a failing/missing worker being restarted by every keypress.
          state.time = os.time()
          if failed then failed('Background project scan timed out. Check PowerShell 7 and Git on PATH.') end
          return
        end
        wezterm.time.call_after(0.2, poll)
      end
      wezterm.time.call_after(0.2, poll)
    end)
  end

  return api
end

return M
