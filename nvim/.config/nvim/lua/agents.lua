local M = { jobs = {}, next_id = 0 }

local function norm(path)
    return vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/+$", "")
end

function M.show(entry)
    if not entry or not vim.api.nvim_buf_is_valid(entry.buf) then return end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == entry.buf then
            vim.api.nvim_set_current_win(win)
            return
        end
    end
    vim.cmd("botright 14split")
    vim.api.nvim_win_set_buf(0, entry.buf)
    vim.wo.number, vim.wo.relativenumber, vim.wo.signcolumn = false, false, "no"
    vim.wo.statuscolumn, vim.wo.foldcolumn = "", "0"
    vim.wo.winbar = " " .. entry.label .. " | " .. entry.root:gsub("%%", "%%%%")
    if entry.status == "running" then vim.cmd.startinsert() end
end

-- A job owns an immutable cwd. Hiding its buffer or opening another project never stops it.
function M.launch(command, root, label, show, kind)
    root = norm(root or vim.fn.getcwd())
    if type(command) == "table" and vim.fn.has("win32") == 1 then
        local executable = vim.fn.exepath(command[1])
        if executable == "" then executable = command[1] end
        if executable:lower():match("%.cmd$") or executable:lower():match("%.bat$") then
            local arguments = { executable }
            vim.list_extend(arguments, vim.list_slice(command, 2))
            local quoted = vim.tbl_map(function(arg) return '"' .. arg:gsub('"', '""') .. '"' end, arguments)
            command = { "cmd.exe", "/d", "/s", "/c", '"' .. table.concat(quoted, " ") .. '"' }
        end
    end
    M.next_id = M.next_id + 1
    local entry = { id = M.next_id, root = root, label = label or "Agent", status = "running", kind = kind or "agent" }
    entry.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[entry.buf].bufhidden = "hide"
    vim.b[entry.buf].agent_id = entry.id
    M.jobs[#M.jobs + 1] = entry
    vim.api.nvim_buf_call(entry.buf, function()
        entry.job = vim.fn.jobstart(command, {
            term = true, cwd = root,
            on_exit = function(_, code)
                vim.schedule(function()
                    entry.exit_code = code
                    entry.status = entry.stop_requested and "stopped" or (code == 0 and "exited" or "failed")
                    vim.notify(entry.label .. " " .. entry.status .. " (" .. code .. ") | " .. vim.fs.basename(root),
                        code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
                    vim.cmd.redrawstatus()
                end)
            end,
        })
    end)
    if entry.job <= 0 then
        entry.status = "failed"
        vim.notify("Could not start " .. entry.label .. ". Check its executable and authentication.", vim.log.levels.ERROR)
    end
    if show ~= false then M.show(entry) end
    return entry
end

function M.start()
    local options = {}
    for _, name in ipairs({ "codex", "claude", "copilot", "opencode" }) do
        if vim.fn.executable(name) == 1 then options[#options + 1] = name end
    end
    options[#options + 1] = "Custom command..."
    local root = vim.fn.getcwd()
    vim.ui.select(options, { prompt = "Agent for " .. vim.fs.basename(root) }, function(name)
        if not name then return end
        if name == "Custom command..." then
            vim.ui.input({ prompt = "Agent command: " }, function(cmd)
                if cmd and vim.trim(cmd) ~= "" then M.launch(cmd, root, cmd) end
            end)
        else
            M.launch({ vim.fn.exepath(name) }, root, name)
        end
    end)
end

function M.pick(callback)
    local entries = vim.tbl_filter(function(e) return vim.api.nvim_buf_is_valid(e.buf) end, M.jobs)
    if #entries == 0 then return vim.notify("No agent or task terminals yet. Space an starts an agent.") end
    vim.ui.select(entries, {
        prompt = "Agents / tasks (all projects)",
        format_item = function(e) return string.format("%d  %-7s  %s | %s", e.id, e.status, e.label, e.root) end,
    }, callback or M.show)
end

function M.hide()
    if not vim.b.agent_id then return end
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then vim.cmd.hide() else vim.cmd.enew() end
end

function M.stop()
    M.pick(function(entry)
        if not entry or entry.status ~= "running" then return end
        if vim.fn.confirm("Stop " .. entry.label .. " in " .. entry.root .. "?", "&Stop\n&Cancel", 2) == 1 then
            entry.stop_requested = true
            vim.fn.jobstop(entry.job)
        end
    end)
end

function M.running(root)
    local count = 0
    for _, entry in ipairs(M.jobs) do
        if entry.status == "running" and (not root or norm(entry.root) == norm(root)) then count = count + 1 end
    end
    return count
end

function M.status()
    local count = M.running()
    return count > 0 and ("jobs " .. count) or ""
end

function M.task(action)
    local root = vim.fn.getcwd()
    local windows = vim.fn.has("win32") == 1
    local candidates = windows and { "mvnw.cmd", "gradlew.bat" } or { "mvnw", "gradlew" }
    local cmd
    for _, file in ipairs(candidates) do
        if vim.fn.filereadable(root .. "/" .. file) == 1 then cmd = { root .. "/" .. file }; break end
    end
    if not cmd and vim.fn.filereadable(root .. "/pom.xml") == 1 and vim.fn.executable("mvn") == 1 then cmd = { "mvn" } end
    if not cmd and (vim.fn.filereadable(root .. "/build.gradle") == 1 or vim.fn.filereadable(root .. "/build.gradle.kts") == 1)
        and vim.fn.executable("gradle") == 1 then cmd = { "gradle" } end
    if not cmd then return vim.notify("No Maven/Gradle wrapper or executable in this project. Use Space tn for a shell.", vim.log.levels.WARN) end
    local maven = vim.fs.basename(cmd[1]):find("mvn", 1, true) ~= nil
    vim.list_extend(cmd, action == "test" and { "test" } or (maven and { "package", "-DskipTests" } or { "assemble" }))
    return M.launch(cmd, root, action, true, "task")
end

function M.setup()
    vim.api.nvim_create_user_command("Agent", function(args)
        if args.args == "" then M.start() else M.launch(args.args, nil, args.args) end
    end, { nargs = "*", desc = "Start an agent in this project" })
    vim.api.nvim_create_user_command("Agents", function() M.pick() end, { desc = "All agent / task terminals" })
    vim.api.nvim_create_user_command("AgentStop", M.stop, { desc = "Stop an agent / task" })
end

return M
