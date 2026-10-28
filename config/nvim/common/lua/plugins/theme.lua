return
{
    {
        "NTBBloodbath/doom-one.nvim",
        lazy = false,
        priority = 1100,
        init = function()
            vim.opt.background = "dark"
            vim.g.doom_one_terminal_colors = true
            vim.g.doom_one_italic_comments = true
            vim.g.doom_one_enable_treesitter = true
            vim.g.doom_one_transparent_background = false
            vim.g.doom_one_diagnostics_text_color = true
            vim.g.doom_one_plugin_whichkey = true
        end,
    },
    {
        "navarasu/onedark.nvim",
        config = function()
            require('onedark').setup {
            }
        end
    },
    {
        'Mofiqul/vscode.nvim',
        lazy = true,
        config = function()
            require('vscode').setup({
                transparent = false,
                italic_comments = true,
                italic_inlayhints = true,
                underline_links = true,
                disable_nvimtree_bg = true,
            })
        end
    },
    {
        'vague-theme/vague.nvim',
        config = function()
            require("vague").setup({
                transparent = true
            })
        end
    },
    {
        "folke/tokyonight.nvim",
        lazy = true,
    },
    {
        'sainnhe/gruvbox-material',
        lazy = true,
        config = function()
            -- Optionally configure and load the colorscheme
            -- directly inside the plugin declaration.
            vim.g.gruvbox_material_enable_italic = true
        end
    }
}
