return {
    {
        "neovim/nvim-lspconfig", -- provides the default server configs used by vim.lsp.enable
        dependencies = { { "j-hui/fidget.nvim", opts = {} } }, -- LSP progress notifications
    },
    {
        -- Installs the servers and enables them (jdtls is started per project by nvim-jdtls below).
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "neovim/nvim-lspconfig",
        },
        opts = {
            ensure_installed = { "lua_ls", "ts_ls", "angularls", "tailwindcss", "clangd", "jdtls" },
            automatic_enable = { exclude = { "jdtls" } },
        },
    },
    {
        "mfussenegger/nvim-jdtls",
        ft = "java",
        dependencies = { "mason-org/mason.nvim" },
        config = function()
            local function start()
                local root = vim.fs.root(0, { "gradlew", "mvnw", "pom.xml", "build.gradle", "build.gradle.kts", ".git" })
                if not root then return end

                local jdtls_bin = vim.fn.exepath("jdtls")
                if jdtls_bin == "" then
                    return vim.notify("jdtls is not installed yet, see :Mason", vim.log.levels.WARN)
                end

                -- jdtls needs its own workspace directory per project
                local workspace = vim.fn.stdpath("cache") .. "/jdtls/workspace/" .. root:gsub("[/\\:]", "_")

                require("jdtls").start_or_attach({
                    cmd = { jdtls_bin, "-data", workspace },
                    root_dir = root,
                    capabilities = require("blink.cmp").get_lsp_capabilities(),
                })
            end

            vim.api.nvim_create_autocmd("FileType", { pattern = "java", callback = start })
            start()
        end,
    },
    {
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
            library = {
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },
    {
        "saghen/blink.cmp",
        version = "1.*",
        opts = {
            sources = {
                default = { "lazydev", "lsp", "path", "snippets", "buffer" },
                providers = {
                    lazydev = {
                        name = "LazyDev",
                        module = "lazydev.integrations.blink",
                        score_offset = 100, -- lazydev completions first
                    },
                },
            },
            keymap = { preset = "enter" },
            completion = {
                menu = { draw = { columns = { { "label", "label_description", gap = 1 }, { "kind" }, { "source_name" } } } },
                documentation = { auto_show = true, auto_show_delay_ms = 500 },
            },
            signature = { enabled = true },
        },
    },
}
