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
            ensure_installed = { "lua_ls", "ts_ls", "angularls", "tailwindcss", "clangd" },
            automatic_enable = { exclude = { "jdtls" } }, -- nvim-java installs and enables jdtls itself
        },
    },
    {
        -- Manages jdtls (with Lombok, Spring Boot tools, test runner and debugger).
        "nvim-java/nvim-java",
        ft = "java",
        config = function()
            require("java").setup()
            vim.lsp.config("jdtls", {
                capabilities = require("blink.cmp").get_lsp_capabilities(),
            })
            vim.lsp.enable("jdtls")
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
