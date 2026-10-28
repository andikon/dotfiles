local M = { config = { root = "~/Code", restore_session = true, dashboard_limit = 6 } }
local data_dir = vim.fn.stdpath("data") .. "/projects.nvim"
local history_file, session_dir = data_dir .. "/history.json", data_dir .. "/sessions"

local function norm(path)
    return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p")):gsub("/+$", "")
end
local function key(path)
    path = norm(path)
    return vim.fn.has("win32") == 1 and path:lower() or path
end
local function read(path)
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then return {} end
    local decoded, value = pcall(vim.json.decode, table.concat(lines, "\n"))
    return decoded and type(value) == "table" and value or {}
end
local function write(path, value)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile({ vim.json.encode(value) }, path)
end
local function session_file(path) return session_dir .. "/" .. vim.fn.sha256(key(path)) .. ".json" end
local function touch(path)
    local history = read(history_file)
    history[key(path)] = { path = norm(path), time = os.time() }
    write(history_file, history)
end
function M.current() return norm(vim.t.project_root or vim.fn.getcwd()) end

function M.list()
    local history, result, seen = read(history_file), {}, {}
    local function add(path)
        path = norm(path)
        if seen[key(path)] or vim.fn.isdirectory(path) ~= 1 then return end
        seen[key(path)] = true
        local record = history[key(path)]
        result[#result + 1] = {
            path = path, name = vim.fs.basename(path),
            last_opened = type(record) == "table" and record.time or 0,
            current = key(path) == key(M.current()),
            has_session = vim.fn.filereadable(session_file(path)) == 1,
        }
    end
    local root = norm(M.config.root)
    if vim.fn.isdirectory(root) == 1 then
        for name, kind in vim.fs.dir(root) do
            if kind == "directory" and name:sub(1, 1) ~= "." then add(root .. "/" .. name) end
        end
    end
    for _, record in pairs(history) do
        if type(record) == "table" and record.path then add(record.path) end
    end
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        if vim.t[tab].project_root then add(vim.t[tab].project_root) end
    end
    table.sort(result, function(a, b)
        if a.last_opened ~= b.last_opened then return a.last_opened > b.last_opened end
        return a.name:lower() < b.name:lower()
    end)
    return result
end

-- Store only file views; no terminal process or arbitrary Vim script is serialized.
local function capture(layout)
    if layout[1] == "leaf" then
        local win = layout[2]
        local buf = vim.api.nvim_win_get_buf(win)
        local path = vim.api.nvim_buf_get_name(buf)
        if vim.bo[buf].buftype ~= "" or path == "" then return nil end
        return { kind = "leaf", path = path, view = vim.api.nvim_win_call(win, vim.fn.winsaveview) }
    end
    local children = {}
    for _, child in ipairs(layout[2]) do
        local node = capture(child)
        if node then children[#children + 1] = node end
    end
    if #children == 0 then return nil end
    return #children == 1 and children[1] or { kind = layout[1], children = children }
end

function M.save_session()
    if M.closing then return end
    local layout = capture(vim.fn.winlayout())
    if not layout then return end
    write(session_file(M.current()), { layout = layout, active = vim.api.nvim_buf_get_name(0) })
end

function M.close()
    M.save_session()
    M.closing = true
    local ok, err = pcall(vim.cmd.tabclose)
    M.closing = false
    if not ok then vim.notify(err, vim.log.levels.WARN) end
end

local function restore(node)
    if type(node) ~= "table" then return end
    if node.kind == "leaf" then
        if type(node.path) == "string" and vim.fn.filereadable(node.path) == 1 then
            vim.cmd.edit(vim.fn.fnameescape(node.path))
            if type(node.view) == "table" then pcall(vim.fn.winrestview, node.view) end
        end
        return
    end
    if not vim.tbl_contains({ "row", "col" }, node.kind) or type(node.children) ~= "table" then return end
    local windows = { vim.api.nvim_get_current_win() }
    for _ = 2, #node.children do
        vim.cmd(node.kind == "row" and "vsplit" or "split")
        windows[#windows + 1] = vim.api.nvim_get_current_win()
    end
    for i, child in ipairs(node.children) do
        vim.api.nvim_set_current_win(windows[i])
        restore(child)
    end
end

function M.open(path)
    path = norm(path)
    if vim.fn.isdirectory(path) ~= 1 then return vim.notify("Project directory does not exist: " .. path, vim.log.levels.ERROR) end
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        if vim.t[tab].project_root and key(vim.t[tab].project_root) == key(path) then
            vim.api.nvim_set_current_tabpage(tab)
            touch(path)
            return
        end
    end
    M.save_session()
    local buf = vim.api.nvim_get_current_buf()
    local empty = #vim.api.nvim_tabpage_list_wins(0) == 1
        and (vim.bo[buf].filetype == "snacks_dashboard" or
            (vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified))
    if not empty then vim.cmd.tabnew() end
    vim.t.project_root, vim.t.workspace_name = path, vim.fs.basename(path)
    vim.cmd.tcd(vim.fn.fnameescape(path))
    touch(path)
    local session = M.config.restore_session and read(session_file(path)) or {}
    if session.layout then
        restore(session.layout)
        vim.cmd("wincmd =")
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == session.active then
                vim.api.nvim_set_current_win(win)
                break
            end
        end
    else
        Snacks.picker.files({ cwd = path })
    end
    vim.api.nvim_exec_autocmds("User", { pattern = "ProjectOpened", data = { path = path } })
end

function M.create()
    vim.ui.input({ prompt = "New project name: " }, function(name)
        name = name and vim.trim(name)
        if not name or name == "" then return end
        if name:find("[/\\]") or name == "." or name == ".." then
            return vim.notify("Use a folder name without path separators.", vim.log.levels.WARN)
        end
        local path = norm(M.config.root) .. "/" .. name
        vim.fn.mkdir(path, "p")
        M.open(path)
    end)
end

function M.pick()
    Snacks.picker({
        title = "Projects  (Enter open / return, Ctrl-n new, Ctrl-x forget session)",
        finder = function()
            return vim.tbl_map(function(p) return vim.tbl_extend("force", p, { text = p.name, file = p.path }) end, M.list())
        end,
        format = function(item)
            return { { item.current and "● " or "  ", "DiagnosticOk" }, { item.name, "Title" },
                { item.has_session and "  session" or "", "Special" }, { "  " .. item.path, "Comment" } }
        end,
        preview = "file",
        confirm = function(picker, item)
            picker:close()
            if item then vim.schedule(function() M.open(item.path) end) end
        end,
        actions = {
            project_new = function(picker) picker:close(); M.create() end,
            project_forget = function(picker, item)
                if item then os.remove(session_file(item.path)) end
                picker:find()
            end,
        },
        win = { input = { keys = {
            ["<c-n>"] = { "project_new", mode = { "n", "i" } },
            ["<c-x>"] = { "project_forget", mode = { "n", "i" } },
        } } },
    })
end

function M.dashboard_section()
    return function()
        local section = { { title = "Projects", padding = 1 } }
        for i, project in ipairs(M.list()) do
            if i > M.config.dashboard_limit then break end
            section[#section + 1] = { desc = project.name, key = tostring(i), action = function() M.open(project.path) end }
        end
        section[#section].padding = 1
        return section
    end
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    vim.t.project_root = norm(vim.fn.getcwd())
    local group = vim.api.nvim_create_augroup("projects.nvim", { clear = true })
    vim.api.nvim_create_user_command("Projects", M.pick, { desc = "Open or return to a project" })
    vim.api.nvim_create_user_command("ProjectNew", M.create, { desc = "Create a project" })
    vim.api.nvim_create_user_command("ProjectOpen", function(args) M.open(args.args) end, { nargs = 1, complete = "dir", desc = "Open a project directory" })
    vim.api.nvim_create_user_command("ProjectSave", M.save_session, { desc = "Save this project's file layout" })
    vim.api.nvim_create_user_command("ProjectClose", M.close, { desc = "Save layout and close the project tab" })
    vim.api.nvim_create_autocmd({ "TabLeave", "VimLeavePre" }, { group = group, callback = M.save_session })
    vim.api.nvim_create_autocmd("BufWritePost", { group = group, callback = function() M.save_session() end })
end

return M
