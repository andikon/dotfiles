local M = {}

---@return boolean ok, string out, string err
function M.run(args, cwd)
  local cmd = vim.list_extend({ "git" }, args)
  local r = vim.system(cmd, { cwd = cwd or vim.uv.cwd(), text = true }):wait()
  return r.code == 0, vim.trim(r.stdout or ""), vim.trim(r.stderr or "")
end

---@class worktree.Repo
---@field main_dir string directory of the main checkout (or the bare repo)
---@field name string
---@field toplevel string|nil worktree the cwd is currently in

---@return worktree.Repo|nil
function M.repo()
  local ok, common = M.run({ "rev-parse", "--path-format=absolute", "--git-common-dir" })
  if not ok then return nil end
  common = vim.fs.normalize(common)
  local main_dir = vim.fs.basename(common) == ".git" and vim.fs.dirname(common) or common
  local has_top, top = M.run({ "rev-parse", "--show-toplevel" })
  return {
    main_dir = main_dir,
    name = vim.fs.basename(main_dir):gsub("%.git$", ""),
    toplevel = has_top and vim.fs.normalize(top) or nil,
  }
end

---@class worktree.Worktree
---@field path string
---@field branch string|nil
---@field bare boolean
---@field detached boolean

---@return worktree.Worktree[]
function M.worktrees()
  local ok, out = M.run({ "worktree", "list", "--porcelain" })
  if not ok then return {} end
  local result, cur = {}, nil
  for line in (out .. "\n"):gmatch("(.-)\r?\n") do
    local path = line:match("^worktree (.+)")
    if path then
      cur = { path = vim.fs.normalize(path), bare = false, detached = false }
      table.insert(result, cur)
    elseif cur then
      local branch = line:match("^branch refs/heads/(.+)")
      if branch then cur.branch = branch end
      if line == "bare" then cur.bare = true end
      if line == "detached" then cur.detached = true end
    end
  end
  return result
end

---@class worktree.Branch
---@field name string local name (without remote prefix)
---@field ref string what git should check out/track
---@field remote string|nil
---@field date string

---@return worktree.Branch[]
function M.branches()
  local ok, out = M.run({
    "for-each-ref", "--sort=-committerdate",
    "--format=%(refname)%09%(refname:short)%09%(committerdate:relative)",
    "refs/heads", "refs/remotes",
  })
  if not ok then return {} end

  local locals, remotes, seen = {}, {}, {}
  for line in out:gmatch("[^\r\n]+") do
    local full, short, date = line:match("^(.-)\t(.-)\t(.*)$")
    if full and full:match("^refs/heads/") then
      seen[short] = true
      table.insert(locals, { name = short, ref = short, date = date })
    elseif full and not full:match("/HEAD$") then
      local remote, name = short:match("^([^/]+)/(.+)$")
      if remote then table.insert(remotes, { name = name, ref = short, remote = remote, date = date }) end
    end
  end
  for _, b in ipairs(remotes) do
    if not seen[b.name] then
      seen[b.name] = true
      table.insert(locals, b)
    end
  end
  return locals
end

return M
