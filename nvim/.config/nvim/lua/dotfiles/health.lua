local M = {}
function M.check()
    vim.health.start("Java / agent workflow")
    if vim.fn.has("nvim-0.12") == 1 then vim.health.ok("Neovim 0.12+")
    else vim.health.error("Use Neovim 0.12+ for this configuration") end
    for _, executable in ipairs({ "git", "curl", "rg" }) do
        if vim.fn.executable(executable) == 1 then vim.health.ok(executable .. " found")
        else vim.health.warn("Install " .. executable .. " and add it to PATH") end
    end
    if vim.fn.executable("java") == 1 or (vim.env.JAVA_HOME and vim.fn.isdirectory(vim.env.JAVA_HOME) == 1) then
        vim.health.ok("Project Java runtime available; IntelliJ server bundles its own runtime")
    else vim.health.warn("Install the JDK required by your project, or set JAVA_HOME") end
    local available = {}
    for _, executable in ipairs({ "codex", "claude", "copilot", "opencode" }) do
        if vim.fn.executable(executable) == 1 then available[#available + 1] = executable end
    end
    if #available > 0 then vim.health.ok("Agent CLIs: " .. table.concat(available, ", "))
    else vim.health.info("Space an also accepts a custom agent command; install/authenticate your preferred CLI") end
    vim.health.info("Space jl activates IntelliJ. Space aa opens Copilot Chat and its GitHub sign-in flow.")
    vim.health.info("Extra syntax parsers: C compiler + tree-sitter CLI >= 0.26.1, then :ParsersInstall")
end
return M
