return
{
    {
        "navarasu/onedark.nvim",
        config = function()
            require('onedark').setup {
                style = 'warmer'
            }
        end
    },
    {
        'Mofiqul/vscode.nvim',
        config = function()
            require('vscode').setup()
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
        lazy = false,
        priority = 1000,
    },
    {
        'sainnhe/gruvbox-material',
        lazy = false,
        priority = 1000,
        config = function()
            -- Optionally configure and load the colorscheme
            -- directly inside the plugin declaration.
            vim.g.gruvbox_material_enable_italic = true
        end
    }
}
