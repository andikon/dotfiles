return {
    {
        "neovim/nvim-lspconfig", -- REQUIRED: for native Neovim LSP integration
        lazy = false,            -- REQUIRED: tell lazy.nvim to start this plugin at startup
        dependencies = {
            { "j-hui/fidget.nvim", },
        },
        init = function()
        end,
        config = function()
            -- Your LSP settings here
            -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
            function GetLspPath(lspPath)
                local home = vim.fn.expand('$HOME')

                local isLinux = string.find(home, "\\") == nil
                if isLinux then
                    local unixLspDirectory = "/.local/lsp"
                    return unixLspDirectory .. lspPath
                else
                    local windowsLspDirectory = home .. "/languageservers"
                    return string.gsub(windowsLspDirectory .. lspPath, "/", "\\")
                end
            end

            local roslynLspDllPath = GetLspPath("/roslyn")

            vim.env.PATH = vim.env.PATH .. ";" .. roslynLspDllPath
            -- roslyn is handled via the plugin below
            vim.lsp.enable({ "lua_ls", "angularls", "tailwindcss", "ts_ls", "clangd" })
        end,
    },
    {"seblyng/roslyn.nvim"},
    {
        "d7omdev/nuget.nvim",
        config = function()
            require("nuget").setup()
        end,
    },
    {
        "folke/lazydev.nvim",
        ft = "lua", -- only load on lua files
        opts = {
            library = {
                -- See the configuration section for more details
                -- Load luvit types when the `vim.uv` word is found
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },
	{
  'nvim-java/nvim-java',
  config = function()
    require('java').setup()
    vim.lsp.enable('jdtls')
  end,
},
    { -- optional blink completion source for require statements and module annotations
        "saghen/blink.cmp",
		version = '1.*',
        opts = {
            sources = {
                -- add lazydev to your completion providers
                default = { "lazydev", "lsp", "path", "snippets", "buffer" },
                providers = {
                    lazydev = {
                        name = "LazyDev",
                        module = "lazydev.integrations.blink",
                        -- make lazydev completions top priority (see `:h blink.cmp`)
                        score_offset = 100,
                    },
                },
            },
            keymap = { preset = 'enter' },
            completion = {
                menu = { draw = { columns = { { "label", "label_description", gap = 1 }, { "kind" }, { "source_name" } } } },
                documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 500,
                }
            },
            signature = {
                enabled = true,
            },
        },
    }
}
