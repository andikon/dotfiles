return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        lazy = false,
        config = function()
            require("nvim-treesitter").setup({})
            local function highlight(event)
                if vim.bo[event.buf].buftype == "" then pcall(vim.treesitter.start, event.buf) end
            end
            vim.api.nvim_create_autocmd("FileType", {
                group = vim.api.nvim_create_augroup("DotfilesTreesitter", { clear = true }),
                callback = highlight,
            })
            vim.api.nvim_create_user_command("ParsersInstall", function()
                local compiler = false
                for _, name in ipairs({ "cc", "gcc", "clang", "cl", "zig" }) do
                    if vim.fn.executable(name) == 1 then compiler = true end
                end
                if not compiler or vim.fn.executable("tree-sitter") ~= 1 then
                    return vim.notify("Extra parsers need a C compiler and tree-sitter CLI >= 0.26.1. Bundled Markdown/Lua parsers already work.", vim.log.levels.WARN)
                end
                require("nvim-treesitter").install({ "java", "kotlin", "hcl", "terraform", "json", "yaml", "bash", "lua", "markdown", "markdown_inline" })
            end, { desc = "Install Java and configuration-language parsers" })
        end
    },
    {
        "norcalli/nvim-colorizer.lua",
        config = function()
            require 'colorizer'.setup()
        end
    }
}
