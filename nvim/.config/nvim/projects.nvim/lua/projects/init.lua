local M = {}

M.config = {
  ---Folder whose direct subfolders are the projects.
  root = "~/Code",
  ---Restore the previous buffers/windows of a project when opening it.
  restore_session = true,
  ---Max projects listed on the dashboard.
  dashboard_limit = 6,
}

local data_dir = vim.fn.stdpath("data") .. "/projects.nvim"
local history_file = data_dir .. "/history.json"
local session_dir = data_dir .. "/sessions"

local function norm(p)
  return (vim.fs.normalize(p):gsub("/+$", ""))
end

local function same(a, b)
  return a and b and norm(a):lower() == norm(b):lower()
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Projects" })
end

local function root()
  return norm(M.config.root)
end

local function session_file(path)
  return session_dir .. "/" .. norm(path):lower():gsub("[/\\:]", "%%") .. ".vim"
end

local function read_history()
  local f = io.open(history_file, "r")
  if not f then return {} end
  local ok, data = pcall(vim.json.decode, f:read("*a"))
  f:close()
  return ok and type(data) == "table" and data or {}
end

local function touch_history(path)
  local history = read_history()
  history[norm(path):lower()] = os.time()
  vim.fn.mkdir(data_dir, "p")
  local f = io.open(history_file, "w")
  if f then
    f:write(vim.json.encode(history))
    f:close()
  end
end

---@class projects.Project
---@field name string
---@field path string
---@field last_opened number
---@field has_session boolean
---@field current boolean

---Direct subfolders of the root, most recently opened first.
---@return projects.Project[]
function M.list()
  local history = read_history()
  local cwd = vim.uv.cwd()
  local result = {}
  for name, type_ in vim.fs.dir(root()) do
    if type_ == "directory" and name:sub(1, 1) ~= "." then
      local path = root() .. "/" .. name
      table.insert(result, {
        name = name,
        path = path,
        last_opened = history[path:lower()] or 0,
        has_session = vim.uv.fs_stat(session_file(path)) ~= nil,
        current = same(cwd, path),
      })
    end
  end
  table.sort(result, function(a, b)
    if a.last_opened ~= b.last_opened then return a.last_opened > b.last_opened end
    return a.name:lower() < b.name:lower()
  end)
  return result
end

---Project the cwd is inside of, if any.
local function current_project()
  local cwd = norm(vim.uv.cwd() or "")
  local prefix = root():lower() .. "/"
  if cwd:lower():sub(1, #prefix) ~= prefix then return nil end
  return root() .. "/" .. cwd:sub(#prefix + 1):match("^[^/]+")
end

local function has_file_buffers()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted and vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) ~= "" then return true end
  end
  return false
end

function M.save_session()
  local project = current_project()
  if not project or not has_file_buffers() then return end

  -- Explorer/picker/terminal windows can't be restored meaningfully.
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].buftype ~= "" and #vim.api.nvim_list_wins() > 1 then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  local saved = vim.o.sessionoptions
  vim.o.sessionoptions = "buffers,curdir,tabpages,winsize,folds"
  vim.fn.mkdir(session_dir, "p")
  pcall(vim.cmd.mksession, { vim.fn.fnameescape(session_file(project)), bang = true })
  vim.o.sessionoptions = saved
end

---@return boolean continue false if the user cancelled
local function resolve_unsaved()
  local modified = vim.tbl_filter(function(b)
    return vim.bo[b].modified and vim.bo[b].buftype == ""
  end, vim.api.nvim_list_bufs())
  if #modified == 0 then return true end

  local choice = vim.fn.confirm(("%d buffer(s) have unsaved changes."):format(#modified), "&Save all\n&Discard\n&Cancel", 3)
  if choice == 1 then
    vim.cmd("silent! wall")
    return true
  end
  return choice == 2
end

---Fully switches the Neovim instance to the project: closes everything of the old one.
---@param path string
function M.open(path)
  path = norm(path)
  if same(vim.uv.cwd(), path) and has_file_buffers() then return notify("Already in this project") end
  if not resolve_unsaved() then return end

  M.save_session()

  for _, client in ipairs(vim.lsp.get_clients()) do client:stop() end
  vim.cmd("silent! tabonly")
  vim.cmd("silent! only!")
  vim.cmd("silent! %bwipeout!")
  vim.cmd.cd(vim.fn.fnameescape(path))
  touch_history(path)

  local session = session_file(path)
  if M.config.restore_session and vim.uv.fs_stat(session) then
    vim.cmd("silent! source " .. vim.fn.fnameescape(session))
  else
    Snacks.picker.files({ cwd = path })
  end
  notify("Opened " .. vim.fs.basename(path))
end

function M.create()
  vim.ui.input({ prompt = "New project name: " }, function(name)
    name = name and vim.trim(name)
    if not name or name == "" then return end
    local path = root() .. "/" .. name
    if vim.fn.mkdir(path, "p") == 0 and not vim.uv.fs_stat(path) then
      return notify("Could not create " .. path, vim.log.levels.ERROR)
    end
    M.open(path)
  end)
end

local function format_item(item)
  return {
    { item.current and "● " or "  ", "DiagnosticOk" },
    { item.name, item.has_session and "Title" or nil },
    { item.has_session and "  session" or "", "Special" },
    { "  " .. item.path, "Comment" },
  }
end

function M.pick()
  Snacks.picker({
    title = "Projects  (<CR> open · <C-n> new · <C-x> forget session)",
    finder = function()
      return vim.tbl_map(function(p)
        return vim.tbl_extend("force", p, { text = p.name, file = p.path })
      end, M.list())
    end,
    format = format_item,
    preview = "file",
    layout = { preset = "default" },
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(function() M.open(item.path) end) end
    end,
    actions = {
      project_new = function(picker)
        picker:close()
        M.create()
      end,
      project_forget = function(picker, item)
        if item then os.remove(session_file(item.path)) end
        picker:find()
      end,
    },
    win = {
      input = { keys = {
        ["<c-n>"] = { "project_new", mode = { "n", "i" } },
        ["<c-x>"] = { "project_forget", mode = { "n", "i" } },
      } },
    },
  })
end

---Snacks dashboard section listing the most recent projects.
function M.dashboard_section()
  return function()
    local section = { { title = "Projects", padding = 1 } }
    for i, p in ipairs(M.list()) do
      if i > M.config.dashboard_limit then break end
      table.insert(section, {
        icon = " ",
        desc = p.name,
        key = tostring(i),
        action = function() M.open(p.path) end,
      })
    end
    section[#section].padding = 1
    return section
  end
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_create_user_command("Projects", M.pick, { desc = "Open a project" })
  vim.api.nvim_create_user_command("ProjectNew", M.create, { desc = "Create a new project" })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("projects.nvim", { clear = true }),
    callback = M.save_session,
  })
end

return M
