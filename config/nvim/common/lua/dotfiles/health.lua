local M = {}
function M.check()
    vim.health.start("Java / agent workflow")
    if vim.fn.has("nvim-0.12") == 1 then vim.health.ok("Neovim 0.12+")
    else vim.health.error("Use Neovim 0.12+ for this configuration") end
    for _, executable in ipairs({ "git", "curl", "rg" }) do
        if vim.fn.executable(executable) == 1 then vim.health.ok(executable .. " found")
        else vim.health.warn("Install " .. executable .. " and add it to PATH") end
    end
    if vim.fn.executable("jdtls") == 1 then vim.health.ok("JDT LS launcher found")
    else vim.health.warn("Check :Mason for jdtls or put the JDT LS launcher on PATH") end
    if vim.fn.executable("python3") == 1 or vim.fn.executable("python") == 1 then
        vim.health.ok("Python launcher found")
    else vim.health.warn("The JDT LS launcher requires Python 3.9+") end
    local java = vim.fn.has("win32") == 1 and "java.exe" or "java"
    local java_home = vim.env.JDTLS_JAVA_HOME or vim.env.JAVA_HOME
    if java_home and java_home ~= "" then
        local candidate = vim.fs.joinpath(java_home, "bin", java)
        if vim.env.JDTLS_JAVA_HOME or vim.fn.executable(candidate) == 1 then java = candidate end
    end
    if vim.fn.executable(java) == 1 then
        local version = vim.system({ java, "-version" }, { text = true }):wait(3000)
        local major = (version.stderr or ""):match('version "(%d+)')
        if version.code == 0 and major and tonumber(major) >= 21 then
            vim.health.ok("JDT LS Java runtime: " .. major)
        else
            vim.health.warn("JDT LS requires JDK 21 or newer depending on its release. Set JDTLS_JAVA_HOME to a compatible JDK.")
        end
    else vim.health.warn("Install a JDK for JDT LS and check JDTLS_JAVA_HOME, JAVA_HOME, or PATH") end
    local available = {}
    for _, executable in ipairs({ "codex", "claude", "copilot", "opencode" }) do
        if vim.fn.executable(executable) == 1 then available[#available + 1] = executable end
    end
    if #available > 0 then vim.health.ok("Agent CLIs: " .. table.concat(available, ", "))
    else vim.health.info("Space an also accepts a custom agent command; install/authenticate your preferred CLI") end
    vim.health.info("Space aa opens Copilot Chat and its GitHub sign-in flow.")
    vim.health.info("Extra syntax parsers: C compiler + tree-sitter CLI >= 0.26.1, then :ParsersInstall")
end
return M
