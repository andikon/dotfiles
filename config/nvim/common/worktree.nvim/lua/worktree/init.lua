local git = require("worktree.git")

local M = {}

M.config = {
  ---Where new worktrees are created. Default: `<repo>.worktrees/<branch>` next to the main checkout.
  ---@type fun(repo: worktree.Repo, branch: string): string
  path = function(repo, branch)
    local dir = vim.fs.dirname(repo.main_dir) .. "/" .. repo.name .. ".worktrees"
    return dir .. "/" .. branch:gsub("[/\\]", "-")
  end,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Worktree" })
end

local function same_path(a, b)
  return a and b and vim.fs.normalize(a):lower() == vim.fs.normalize(b):lower()
end

---Changes the cwd to the worktree and reopens the current file there if it exists.
function M.switch_to(path, repo)
  if same_path(path, repo.toplevel) then return notify("Already in this worktree") end

  local file = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
  local prefix = repo.toplevel and (vim.fs.normalize(repo.toplevel):gsub("/+$", "") .. "/")
  local candidate = vim.fn.has("win32") == 1 and file:lower() or file
  local match = prefix and (vim.fn.has("win32") == 1 and prefix:lower() or prefix)
  local rel = match and candidate:sub(1, #match) == match and file:sub(#prefix + 1)
  require("projects").open(path)
  if rel and rel ~= "" and not vim.bo.modified and vim.uv.fs_stat(path .. "/" .. rel) then
    vim.cmd.edit(vim.fn.fnameescape(path .. "/" .. rel))
  end
  notify("Switched to " .. path)
end

---Checks out a branch into its own worktree (created on demand) and switches to it.
---@param branch worktree.Branch
function M.checkout(branch)
  local repo = git.repo()
  if not repo then return notify("Not a git repository", vim.log.levels.ERROR) end

  for _, wt in ipairs(git.worktrees()) do
    if wt.branch == branch.name then return M.switch_to(wt.path, repo) end
  end

  local path = M.config.path(repo, branch.name)
  local args = { "worktree", "add" }
  if branch.remote then vim.list_extend(args, { "--track", "-b", branch.name, path, branch.ref })
  else vim.list_extend(args, { path, branch.name }) end

  local ok, _, err = git.run(args)
  if not ok then return notify(err, vim.log.levels.ERROR) end
  M.switch_to(path, repo)
end

---Creates a new branch from HEAD in a new worktree.
function M.create()
  vim.ui.input({ prompt = "New branch name: " }, function(name)
    if not name or vim.trim(name) == "" then return end
    name = vim.trim(name)
    local repo = git.repo()
    if not repo then return notify("Not a git repository", vim.log.levels.ERROR) end
    local path = M.config.path(repo, name)
    local ok, _, err = git.run({ "worktree", "add", "-b", name, path })
    if not ok then return notify(err, vim.log.levels.ERROR) end
    M.switch_to(path, repo)
  end)
end

---@param wt worktree.Worktree
function M.remove(wt, repo)
  if require("agents").running(wt.path) > 0 then return notify("Stop the jobs in this worktree before removing it", vim.log.levels.WARN) end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if vim.t[tab].project_root and same_path(vim.t[tab].project_root, wt.path) then
      return notify("Close this worktree's project tab before removing it", vim.log.levels.WARN)
    end
  end
  if same_path(wt.path, repo.toplevel) then return notify("Cannot remove the current worktree", vim.log.levels.WARN) end
  if same_path(wt.path, repo.main_dir) then return notify("Cannot remove the main worktree", vim.log.levels.WARN) end
  local ok, _, err = git.run({ "worktree", "remove", wt.path })
  if not ok then
    if vim.fn.confirm(err .. "\n\nForce remove?", "&Yes\n&No", 2) ~= 1 then return end
    ok, _, err = git.run({ "worktree", "remove", "--force", wt.path })
    if not ok then return notify(err, vim.log.levels.ERROR) end
  end
  notify("Removed " .. wt.path)
end

local function format_item(item)
  return {
    { item.current and "● " or (item.worktree and "◦ " or "  "), item.current and "DiagnosticOk" or "Special" },
    { item.name, item.worktree and "Title" or nil },
    { item.remote and ("  " .. item.remote) or "", "Comment" },
    { item.date and ("  " .. item.date) or "", "Comment" },
    { item.worktree and ("  " .. item.worktree.path) or "", "Comment" },
  }
end

---@param mode "branches"|"worktrees"
local function pick(mode)
  local repo = git.repo()
  if not repo then return notify("Not a git repository", vim.log.levels.ERROR) end

  local function items()
    repo = git.repo() or repo
    local worktrees = git.worktrees()
    local by_branch = {}
    for _, wt in ipairs(worktrees) do
      if wt.branch then by_branch[wt.branch] = wt end
    end

    local result = {}
    if mode == "worktrees" then
      for _, wt in ipairs(worktrees) do
        local name = wt.branch or (wt.bare and "(bare)") or "(detached)"
        table.insert(result, {
          text = name .. " " .. wt.path, name = name, worktree = wt,
          current = same_path(wt.path, repo.toplevel),
          branch = wt.branch and { name = wt.branch, ref = wt.branch } or nil,
        })
      end
    else
      for _, b in ipairs(git.branches()) do
        local wt = by_branch[b.name]
        table.insert(result, {
          text = b.name, name = b.name, remote = b.remote, date = b.date, worktree = wt,
          current = wt ~= nil and same_path(wt.path, repo.toplevel), branch = b,
        })
      end
      table.sort(result, function(a, b)
        if (a.worktree ~= nil) ~= (b.worktree ~= nil) then return a.worktree ~= nil end
        return false
      end)
    end
    return result
  end

  Snacks.picker({
    title = mode == "branches" and "Git Branches  (<CR> checkout · <C-n> new · <C-d> remove worktree)"
      or "Git Worktrees  (<CR> switch · <C-n> new · <C-d> remove)",
    finder = items,
    format = format_item,
    preview = "none",
    layout = { preset = "select" },
    confirm = function(picker, item)
      picker:close()
      if not item then return end
      if mode == "worktrees" then M.switch_to(item.worktree.path, repo)
      elseif item.branch then M.checkout(item.branch) end
    end,
    actions = {
      worktree_new = function(picker)
        picker:close()
        M.create()
      end,
      worktree_remove = function(picker, item)
        if not item or not item.worktree then return notify("No worktree for this entry", vim.log.levels.WARN) end
        M.remove(item.worktree, repo)
        picker:find()
      end,
    },
    win = {
      input = { keys = {
        ["<c-n>"] = { "worktree_new", mode = { "n", "i" } },
        ["<c-d>"] = { "worktree_remove", mode = { "n", "i" } },
      } },
      list = { keys = {
        ["<c-n>"] = "worktree_new",
        ["<c-d>"] = "worktree_remove",
      } },
    },
  })
end

function M.branches() pick("branches") end
function M.worktrees() pick("worktrees") end

return M
