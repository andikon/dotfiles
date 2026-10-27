return {
    {
        "neovim/nvim-lspconfig", -- provides the default server configs used by vim.lsp.enable
        dependencies = { { "j-hui/fidget.nvim", opts = {} } }, -- LSP progress notifications
    },
    {
        -- IntelliJ owns Java/Kotlin; Mason manages configuration languages.
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "neovim/nvim-lspconfig",
            "saghen/blink.cmp",
        },
        opts = {
            ensure_installed = { "lua_ls", "ts_ls", "angularls", "tailwindcss", "clangd", "terraformls", "jsonls", "yamlls", "bashls" },
            automatic_enable = { exclude = { "jdtls", "kotlin_language_server", "kotlin_lsp" } },
        },
        config = function(_, opts)
            vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
            vim.lsp.config("lua_ls", { settings = { Lua = { diagnostics = { globals = { "vim", "Snacks" } } } } })
            require("mason-lspconfig").setup(opts)
        end,
    },
    {
        "JetBrains/intellij-lsp.nvim",
        lazy = false,
        dependencies = { "mfussenegger/nvim-dap" },
        opts = {
            server_path = vim.env.INTELLIJ_LSP_SERVER,
            default_sdk = vim.env.JAVA_HOME,
            colorscheme = false, keymaps = false, references = false,
            git = false, single_key_select = false, format_on_save = false,
            build_output = "on_failure",
        },
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
            -- IntelliJ's native completion handles its extended Java edits.
            enabled = function() return not vim.tbl_contains({ "java", "kotlin" }, vim.bo.filetype) end,
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
            fuzzy = { implementation = "lua" },
            keymap = { preset = "enter" },
            completion = {
                menu = { draw = { columns = { { "label", "label_description", gap = 1 }, { "kind" }, { "source_name" } } } },
                documentation = { auto_show = true, auto_show_delay_ms = 500 },
            },
            signature = { enabled = true },
        },
    },
}
