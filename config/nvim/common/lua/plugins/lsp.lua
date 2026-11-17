return {
    {
        "neovim/nvim-lspconfig", -- provides the default server configs used by vim.lsp.enable
        dependencies = { { "j-hui/fidget.nvim", opts = {} } }, -- LSP progress notifications
    },
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "neovim/nvim-lspconfig",
            "saghen/blink.cmp",
        },
        opts = {
            ensure_installed = { "lua_ls", "ts_ls", "angularls", "tailwindcss", "clangd", "terraformls", "jsonls", "yamlls", "bashls", "jdtls" },
            -- nvim-jdtls owns Java attachment, including the workspace path.
            automatic_enable = { exclude = { "jdtls" } },
        },
        config = function(_, opts)
            vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
            vim.lsp.config("lua_ls", { settings = { Lua = { diagnostics = { globals = { "vim", "Snacks" } } } } })
            require("mason-lspconfig").setup(opts)
        end,
    },
    {
        "mfussenegger/nvim-jdtls",
        ft = "java",
        dependencies = { "mason-org/mason.nvim", "saghen/blink.cmp", "mfussenegger/nvim-dap" },
        config = function() require("dotfiles.java").setup() end,
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
