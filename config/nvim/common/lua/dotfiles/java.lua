local M = {}

local build_roots = { ".mvn", "mvnw", "mvnw.cmd", "settings.gradle", "settings.gradle.kts", "gradlew", "gradlew.bat" }
local build_files = { "build.gradle", "build.gradle.kts", "build.xml", ".project" }

local function has_marker(dir, markers)
    for _, marker in ipairs(markers) do
        if vim.uv.fs_stat(vim.fs.joinpath(dir, marker)) then return true end
    end
    return false
end

local function project_root(file)
    local start = vim.fs.dirname(file)
    local dir, maven_root, fallback = start, nil, nil
    while dir do
        if has_marker(dir, build_roots) then return dir end
        -- Wrapperless Maven reactors use the outermost POM within the checkout.
        if vim.uv.fs_stat(vim.fs.joinpath(dir, "pom.xml")) then maven_root = dir end
        if not fallback and has_marker(dir, build_files) then fallback = dir end
        if vim.uv.fs_stat(vim.fs.joinpath(dir, ".git")) then break end
        local parent = vim.fs.dirname(dir)
        if parent == dir then break end
        dir = parent
    end
    return maven_root or fallback or start
end

local function package_name(directory, source_paths)
    local real_directory = vim.uv.fs_realpath(directory)
    if not real_directory then return nil end
    local closest
    for _, path in ipairs(source_paths) do
        local root = vim.uv.fs_realpath(path)
        local relative = root and vim.fs.relpath(root, real_directory)
        if relative == "." then return "" end
        if relative and (not closest or #relative < #closest) then closest = relative end
    end
    return closest and closest:gsub("/", ".")
end

local function new_java_file(client, bufnr)
    if client:is_stopped() then
        vim.notify("Start JDT LS before creating a Java file.", vim.log.levels.WARN)
        return
    end
    local source_uri = vim.uri_from_bufnr(bufnr)
    local directory = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
    vim.ui.input({ prompt = "New Java class name (current package): " }, function(input)
        local name = vim.trim(input or ""):gsub("%.java$", "")
        if name == "" then return end
        if not name:match("^[%a_$][%w_$]*$") then
            vim.notify("Enter a class name such as OrderService.", vim.log.levels.WARN)
            return
        end
        local source_paths_key = "org.eclipse.jdt.ls.core.sourcePaths"
        client:exec_cmd({
            command = "java.project.getSettings",
            arguments = { source_uri, { source_paths_key } },
        }, { bufnr = bufnr }, function(err, settings)
            if vim.api.nvim_get_current_buf() ~= bufnr or vim.uri_from_bufnr(bufnr) ~= source_uri then return end
            if err then
                vim.notify("Could not get Java source roots. " .. err.message, vim.log.levels.WARN)
                return
            end
            local source_paths = type(settings) == "table" and settings[source_paths_key]
            local package = vim.islist(source_paths) and package_name(directory, source_paths)
            if not package then
                vim.notify("JDT LS did not find a source root for this file. Check that the project has finished importing.",
                    vim.log.levels.WARN)
                return
            end

            local file = vim.fs.joinpath(directory, name .. ".java")
            local target = vim.fn.bufadd(file)
            if vim.uv.fs_lstat(file) or vim.fn.bufloaded(target) == 1 then
                vim.notify("Java file already exists or is open. " .. name .. ".java", vim.log.levels.WARN)
                return
            end
            vim.fn.bufload(target)
            if vim.uv.fs_lstat(file) or vim.bo[target].modified then
                vim.notify("Java file already has content. " .. name .. ".java", vim.log.levels.WARN)
                return
            end
            local lines = package ~= "" and { "package " .. package .. ";", "" } or {}
            vim.list_extend(lines, { "public class " .. name .. " {", "", "}" })
            vim.api.nvim_buf_set_lines(target, 0, -1, false, lines)
            vim.bo[target].buflisted = true
            vim.api.nvim_set_current_buf(target)
            vim.api.nvim_win_set_cursor(0, { #lines - 1, 0 })
        end)
    end)
end

local function on_attach(client, bufnr)
    local function bind(key, action, desc)
        vim.keymap.set("n", "<leader>" .. key, action, { buffer = bufnr, silent = true, desc = desc })
    end
    bind("ji", "<cmd>checkhealth dotfiles<cr>", "Java prerequisites")
    bind("jo", "<cmd>JdtShowLogs<cr>", "Java server logs")
    bind("jr", "<cmd>JdtUpdateConfig<cr>", "Reload Java build configuration")
    bind("jR", "<cmd>JdtRestart<cr>", "Restart JDT LS")
    bind("ja", require("jdtls").organize_imports, "Organize Java imports")
    if vim.bo[bufnr].buftype == "" and vim.startswith(vim.uri_from_bufnr(bufnr), "file:") then
        bind("jn", function() new_java_file(client, bufnr) end, "New Java class")
    end

    local commands = client.server_capabilities.executeCommandProvider or {}
    if not vim.tbl_contains(commands.commands or {}, "vscode.java.startDebugSession") then return end
    local dap = require("dap")
    bind("rr", function()
        dap.continue({ new = true, before = function(config)
            return vim.tbl_extend("force", config, { noDebug = true })
        end })
    end, "Run Java main class")
    bind("rd", function() dap.continue({ new = true }) end, "Debug Java main class")
    bind("rs", dap.terminate, "Stop Java run / debug")
end

local function start(bufnr)
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == "" or vim.bo[bufnr].buftype ~= "" or not vim.startswith(vim.uri_from_bufnr(bufnr), "file:") then return end
    -- nvim-jdtls may write missing files on attach. Wait for the user's first save.
    if not vim.uv.fs_stat(file) then return end
    if vim.fn.executable("jdtls") ~= 1 then
        vim.notify_once("JDT LS is unavailable. Check :Mason and reopen the Java file when jdtls is installed.", vim.log.levels.WARN)
        return
    end

    local root = project_root(file)
    root = vim.fs.normalize(vim.uv.fs_realpath(root) or root, { expand_env = false })
    local state = vim.fs.joinpath(vim.fn.stdpath("data"), "jdtls", vim.fn.sha256(root))
    local cmd = { "jdtls", "-data", vim.fs.joinpath(state, "workspace"), "-configuration", vim.fs.joinpath(state, "config") }
    local java_home = vim.env.JDTLS_JAVA_HOME
    if java_home and java_home ~= "" then
        local executable = vim.fn.has("win32") == 1 and "java.exe" or "java"
        vim.list_extend(cmd, { "--java-executable", vim.fs.joinpath(java_home, "bin", executable) })
    end
    local mason_share = vim.fs.joinpath(require("mason.settings").current.install_root_dir, "share")
    local lombok = vim.fs.joinpath(mason_share, "jdtls", "lombok.jar")
    if vim.uv.fs_stat(lombok) then cmd[#cmd + 1] = "--jvm-arg=-javaagent:" .. lombok end
    for arg in (vim.env.JDTLS_JVM_ARGS or ""):gmatch("%S+") do
        cmd[#cmd + 1] = "--jvm-arg=" .. arg
    end
    local debug_adapter = vim.fs.joinpath(mason_share, "java-debug-adapter", "com.microsoft.java.debug.plugin.jar")

    local settings = { java = { maven = { downloadSources = false } } }
    local config = {
        cmd = cmd,
        cmd_cwd = root,
        root_dir = root,
        capabilities = require("blink.cmp").get_lsp_capabilities(),
        init_options = {
            bundles = vim.uv.fs_stat(debug_adapter) and { debug_adapter } or {},
            settings = settings,
        },
        settings = settings,
        on_attach = on_attach,
    }
    vim.api.nvim_buf_call(bufnr, function()
        require("jdtls").start_or_attach(config, nil, { bufnr = bufnr })
    end)
end

function M.setup()
    local group = vim.api.nvim_create_augroup("DotfilesJava", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "java",
        callback = function(event) start(event.buf) end,
    })
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = "*.java",
        callback = function(event)
            if vim.bo[event.buf].filetype == "java"
                and #vim.lsp.get_clients({ name = "jdtls", bufnr = event.buf, _uninitialized = true }) == 0 then
                start(event.buf)
            end
        end,
    })
end

return M
