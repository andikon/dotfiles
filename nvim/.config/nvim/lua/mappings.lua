
local M = {}

function M.setup()
    vim.g.mapleader = " "
    local map = vim.keymap.set

    -------------------------------------------------------------------
    -- SPLIT NAVIGATION (tmux-style)
    -------------------------------------------------------------------
    map("n", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Window up" })
    map("n", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Window down" })
    map("n", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Window left" })
    map("n", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Window right" })

    -- Create splits
    map("n", "_", "<cmd>split<cr>", { desc = "Horizontal split" })
    map("n", "|", "<cmd>vsplit<cr>", { desc = "Vertical split" })

    -------------------------------------------------------------------
    -- INDENTATION (VISUAL MODE)
    -------------------------------------------------------------------
    map("v", "<", "<gv", { desc = "Indent left" })
    map("v", ">", ">gv", { desc = "Indent right" })

    -------------------------------------------------------------------
    -- TEXT MANIPULATION
    -------------------------------------------------------------------
    -- Move selected block
    map("x", "J", "<cmd>move '>+1<cr>gv-gv", { desc = "Move block down" })
    map("x", "K", "<cmd>move '<-2<cr>gv-gv", { desc = "Move block up" })

    -- Don't pollute registers
    map("n", "c", '"_c', { desc = "Change (no register)" })
    map("n", "C", '"_C', { desc = "Change to EOL (no register)" })

    -- Clipboard paste in insert mode
    map("i", "<C-v>", "<C-r>*", { desc = "Paste from clipboard" })

    -- Yank to end of line
    map("n", "Y", "y$", { desc = "Yank to end of line" })

    -------------------------------------------------------------------
    -- LSP
    -------------------------------------------------------------------
    map("n", "gd", function() Snacks.picker.lsp_definitions() end, { desc = "Go to definition" })
    map("n", "gD", function() Snacks.picker.lsp_declarations() end, { desc = "Go to declaration" })
    map("n", "gI", function() Snacks.picker.lsp_implementations() end, { desc = "Go to implementation" })
    map("n", "gr", function() Snacks.picker.lsp_references() end, { desc = "Go to references" })

    map("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
    map("n", "gk", vim.lsp.buf.signature_help, { desc = "Signature help" })
    map("n", "ge", vim.diagnostic.open_float, { desc = "Diagnostics float" })
    map("n", "gE", function()
        vim.diagnostic.open_float({ scope = "cursor" })
    end, { desc = "Diagnostics float (cursor)" })

    map("n", "[e", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
    map("n", "]e", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

    -- Leader mappings
    map("n", "<leader>cf", function()
        vim.lsp.buf.format({ async = true })
    end, { desc = "Format" })

    map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
    map("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename symbol" })

    require("agents").setup()
    local function bind(key, action, desc, mode)
        map(mode or "n", key, action, { desc = desc, silent = true })
    end
    bind("<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")
    bind("<leader>ff", function() Snacks.picker.files({ cwd = vim.fn.getcwd() }) end, "Find project file")
    bind("<leader>fr", function() Snacks.picker.recent({ filter = { cwd = true } }) end, "Recent project files")
    bind("<leader>fg", function() Snacks.picker.grep({ cwd = vim.fn.getcwd() }) end, "Search project text")
    bind("<leader>fn", "<cmd>enew<cr>", "New file")
    bind("<leader>fs", "<cmd>write<cr>", "Save file")
    bind("<leader>fS", "<cmd>wall<cr>", "Save all files")
    bind("<leader>bl", function() Snacks.picker.buffers({ filter = { cwd = true } }) end, "Project buffers")
    bind("<leader>bd", function()
        if vim.b.agent_id then require("agents").hide() else Snacks.bufdelete() end
    end, "Close buffer / hide agent")
    bind("<S-h>", "<cmd>bprevious<cr>", "Previous buffer")
    bind("<S-l>", "<cmd>bnext<cr>", "Next buffer")
    bind("<leader>ps", function() require("projects").save_session() end, "Save project layout")
    bind("<leader>pd", function()
        vim.ui.input({ prompt = "Open project directory: ", completion = "dir" }, function(path)
            if path and path ~= "" then require("projects").open(path) end
        end)
    end, "Open project directory")
    bind("<leader><tab>n", function()
        local root = vim.fn.getcwd()
        vim.cmd.tabnew()
        vim.cmd.tcd(vim.fn.fnameescape(root))
        vim.t.project_root = root
    end, "New view tab")
    bind("<leader><tab>r", function()
        vim.ui.input({ prompt = "Tab name: " }, function(name)
            if name and name ~= "" then vim.t.workspace_name = name; vim.cmd.redrawtabline() end
        end)
    end, "Rename tab")
    bind("<leader><tab>x", function() require("projects").close() end, "Save and close tab")
    bind("<leader><tab>]", "<cmd>tabnext<cr>", "Next tab")
    bind("<leader><tab>[", "<cmd>tabprevious<cr>", "Previous tab")
    bind("<leader>an", function() require("agents").start() end, "New CLI agent")
    bind("<leader>al", function() require("agents").pick() end, "All agents / tasks")
    bind("<leader>ah", function() require("agents").hide() end, "Hide agent terminal")
    bind("<leader>as", function() require("agents").stop() end, "Stop agent / task")
    bind("<leader>rb", function() require("agents").task("build") end, "Build project")
    bind("<leader>rt", function() require("agents").task("test") end, "Test project")
    bind("<leader>rr", "<cmd>IntellijLspRun<cr>", "Run Java at cursor")
    bind("<leader>rd", function() require("intellij-lsp.run").run_at_cursor(false) end, "Debug Java at cursor")
    bind("<leader>rl", vim.lsp.codelens.run, "Run Java code lens")
    bind("<leader>rs", "<cmd>IntellijLspRunStop<cr>", "Stop Java run / build")
    bind("<leader>db", function() require("dap").toggle_breakpoint() end, "Toggle breakpoint")
    bind("<leader>dB", function()
        vim.ui.input({ prompt = "Breakpoint condition: " }, function(value)
            if value and value ~= "" then require("dap").set_breakpoint(value) end
        end)
    end, "Conditional breakpoint")
    for key, spec in pairs({
        dc = { "continue", "Continue debugger" }, dn = { "step_over", "Step over" },
        di = { "step_into", "Step into" }, ["do"] = { "step_out", "Step out" },
        dq = { "stop", "Stop debugger" }, dv = { "open", "Debug panel" },
    }) do
        local fn = spec[1]
        bind("<leader>" .. key, function() require("intellij-lsp.debug")[fn]() end, spec[2])
    end
    bind("<leader>de", function() require("intellij-lsp.debug").evaluate_at_cursor() end, "Evaluate expression", { "n", "x" })
    bind("<leader>dw", function() require("intellij-lsp.debug").watch_at_cursor() end, "Watch expression", { "n", "x" })
    bind("<leader>ji", "<cmd>checkhealth intellij-lsp<cr>", "IntelliJ health")
    bind("<leader>jl", "<cmd>IntellijLspLicense<cr>", "IntelliJ license / sign in")
    bind("<leader>jo", "<cmd>IntellijLspOutput<cr>", "Java import / build output")
    bind("<leader>jr", "<cmd>IntellijLspReload<cr>", "Reload Java project")
    bind("<leader>jR", "<cmd>IntellijLspRestart<cr>", "Restart IntelliJ server")
    bind("<leader>jn", "<cmd>IntellijLspFileTemplate<cr>", "Java file template")
    bind("<leader>cs", function() Snacks.picker.lsp_symbols() end, "Document symbols / outline")
    bind("<leader>cS", function() Snacks.picker.lsp_workspace_symbols() end, "Workspace symbols")
    bind("<leader>ci", vim.lsp.buf.incoming_calls, "Incoming calls")
    bind("<leader>co", vim.lsp.buf.outgoing_calls, "Outgoing calls")
    bind("<leader>uh", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
    end, "Toggle inlay hints")
    bind("<leader>ud", function()
        local current = vim.diagnostic.config().virtual_lines
        if current then vim.diagnostic.config({ virtual_lines = false })
        else vim.diagnostic.config({ virtual_lines = { current_line = true } }) end
    end, "Toggle diagnostic messages")
    bind("<leader>un", function() Snacks.notifier.show_history() end, "Notification history")
    bind("<leader>uH", "<cmd>checkhealth dotfiles<cr>", "Workflow health / prerequisites")
    bind("<leader>?", function() require("which-key").show({ global = false }) end, "Show buffer shortcuts")
    bind("<leader>qq", "<cmd>confirm qall<cr>", "Quit Neovim")
    bind("<Esc><Esc>", "<C-\\><C-n>", "Terminal normal mode", "t")

    vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("DotfilesLspKeys", { clear = true }),
        callback = function(event)
            local client = vim.lsp.get_client_by_id(event.data.client_id)
            if not client or client.name ~= "intellij" then return end
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(event.buf) then return end
                -- The upstream debugger's bare leader-b would hide our whole buffer group.
                pcall(vim.keymap.del, "n", "<leader>b", { buffer = event.buf })
                pcall(vim.keymap.del, "n", "<leader>B", { buffer = event.buf })
                vim.keymap.set("i", "<C-Space>", vim.lsp.completion.get, { buffer = event.buf, desc = "Java completion" })
            end)
        end,
    })
end

return M
