local header = {
  [[______  _____  _____ ___  ___]],
  [[|  _  \|  _  ||  _  ||  \/  |]],
  [[| | | || | | || | | || .  . |]],
  [[| | | || | | || | | || |\/| |]],
  [[| |/ / \ \_/ /\ \_/ /| |  | |]],
  [[|___/   \___/  \___/ \_|  |_/]],
}

-- Split into characters so the glitch code works per column.
local header_chars = vim.tbl_map(function(line) return vim.fn.split(line, "\\zs") end, header)
local COLS = #header_chars[1]

local frame_ms = 80 -- time between animation frames
local frame = 0

local PAD = 4 -- spare columns on each side so glitched rows can shift
local WIDTH = COLS + PAD * 2

local function set_highlights()
  vim.api.nvim_set_hl(0, "DoomMain", { fg = "#ff2a6d", bold = true })
  vim.api.nvim_set_hl(0, "DoomScan", { fg = "#ffffff", bold = true })
  vim.api.nvim_set_hl(0, "DoomGlitchCyan", { fg = "#05d9e8", bold = true })
  vim.api.nvim_set_hl(0, "DoomGlitchWhite", { fg = "#d1f7ff", bold = true })
end

local GLITCH_CHARS = { "#", "%", "/", "\\", "|", "_", "▓", "░" }
local glitch = { left = 0, next = 20, offsets = {}, noise = {} }

-- Mostly static; every so often a short burst shifts random rows sideways and corrupts characters.
local function advance()
  frame = frame + 1
  if glitch.left > 0 then
    glitch.left = glitch.left - 1
  elseif frame >= glitch.next then
    glitch.left = math.random(2, 4)
    glitch.next = frame + math.random(12, 35)
  end

  glitch.offsets, glitch.noise = {}, {}
  if glitch.left > 0 then
    for row = 1, #header do
      if math.random() < 0.5 then glitch.offsets[row] = math.random(-4, 4) end
    end
    for _ = 1, math.random(4, 10) do
      glitch.noise[math.random(#header) .. ":" .. math.random(COLS)] = GLITCH_CHARS[math.random(#GLITCH_CHARS)]
    end
  end
end

local function header_section()
  local scan = math.floor(frame / 2) % (#header + 8) + 1 -- row lit by the scanline
  local items = {}
  for row, line in ipairs(header_chars) do
    local shift = glitch.offsets[row] or 0
    local cells = {}
    for c = 1, #line do
      local ch = line[c]
      local hl = row == scan and "DoomScan" or "DoomMain"
      local noise = glitch.noise[row .. ":" .. c]
      if noise then
        ch, hl = noise, "DoomGlitchCyan"
      elseif shift ~= 0 and ch ~= " " then
        hl = shift > 0 and "DoomGlitchCyan" or "DoomGlitchWhite"
      end
      local x = c + PAD + shift
      if x >= 1 and x <= WIDTH then cells[x] = { ch = ch, hl = hl } end
    end

    local text, cur, cur_hl = {}, "", nil
    for x = 1, WIDTH do
      local cell = cells[x]
      local ch, hl = cell and cell.ch or " ", cell and cell.hl or nil
      if hl ~= cur_hl and cur ~= "" then
        table.insert(text, { cur, hl = cur_hl })
        cur = ""
      end
      cur_hl = hl
      cur = cur .. ch
    end
    table.insert(text, { cur, hl = cur_hl })
    table.insert(items, { text = text, align = "center", padding = row == #header and 1 or 0 })
  end
  return items
end

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  init = function()
    set_highlights()
    math.randomseed(os.time())
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights })

    local timer = vim.uv.new_timer()
    timer:start(frame_ms, frame_ms, vim.schedule_wrap(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
          advance()
          Snacks.dashboard.update()
          return
        end
      end
    end))
  end,
  ---@type snacks.Config
  opts = {
    dashboard = {
      preset = {
        keys = {
          { icon = " ", key = "p", desc = "Projects", action = function() require("projects").pick() end },
          { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        header_section,
        { section = "keys", gap = 1, padding = 1 },
        function() return require("projects").dashboard_section()() end,
        { section = "startup" },
      },
    },
    explorer = {
        enabled = true,
    },
    indent = { enabled = true },
    input = { enabled = true },
    notifier = {
      enabled = true,
     timeout = 3000,
    },
    picker = { 
        enabled = true, 
        sources = {
            explorer = {
              hidden = true,
            },
        },
    },
    quickfile = { enabled = true },
    statuscolumn = { enabled = true },
    terminal = { enabled = true },
    words = { enabled = true },
    styles = {
      notification = {
      wo = { wrap = true }
      }
    }
  },
  keys = {
    -- Top Pickers & Explorer
    { "<leader>sf", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
    { "<leader>sb", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
    { "<leader>ss", function() Snacks.picker.grep() end, desc = "Grep" },    
    { "<leader>e", function() Snacks.explorer() end, desc = "File Explorer" },

    -- git
    { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Git Branches" },
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git Log" },
    { "<leader>gL", function() Snacks.picker.git_log_line() end, desc = "Git Log Line" },
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
    { "<leader>gS", function() Snacks.picker.git_stash() end, desc = "Git Stash" },
    { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Git Diff (Hunks)" },

    -- search
    { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
    { '<leader>s/', function() Snacks.picker.search_history() end, desc = "Search History" },
    { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
    { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
    { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
    { "<leader>sM", function() Snacks.picker.man() end, desc = "Man Pages" },
    { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
    { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo History" },
	
    -- terminal
    { "<C-/>", function() Snacks.terminal() end, mode = { "n", "t" }, desc = "Toggle Terminal" },
    { "<leader>tt", function() Snacks.terminal() end, desc = "Toggle Terminal" },
    { "<leader>tn", function() Snacks.terminal(nil, { count = #Snacks.terminal.list() + 1 }) end, desc = "New Terminal" },
    {
      "<leader>tp",
      function()
        local terms = Snacks.terminal.list()
        if #terms == 0 then return Snacks.notify.warn("No terminals open") end
        Snacks.picker.select(terms, {
          prompt = "Terminals",
          format_item = function(t) return ("%d: %s"):format(t.buf, vim.api.nvim_buf_get_name(t.buf)) end,
        }, function(t) if t then t:show():focus() end end)
      end,
      desc = "Pick Terminal",
    },
    -- leave terminal mode / move to neighbouring windows
    { "<Esc><Esc>", "<C-\\><C-n>", mode = "t", desc = "Terminal Normal Mode" },
    { "<C-h>", "<cmd>wincmd h<cr>", mode = "t", desc = "Window left" },
    { "<C-j>", "<cmd>wincmd j<cr>", mode = "t", desc = "Window down" },
    { "<C-k>", "<cmd>wincmd k<cr>", mode = "t", desc = "Window up" },
    { "<C-l>", "<cmd>wincmd l<cr>", mode = "t", desc = "Window right" },

    -- Other
    { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename File" },
  },
}
