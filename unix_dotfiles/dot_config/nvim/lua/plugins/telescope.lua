return {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-treesitter/nvim-treesitter',
        'nvim-telescope/telescope-ui-select.nvim'
    },
    config = function()
        -- This is your opts table
        require("telescope").setup {
            defaults = {
                color_devicons = true,
                sorting_strategy = "ascending",
                layout_config = {
                    prompt_position = "top",
                    width = 9999,
                    height = 9999,
                }
            },
            extensions = {
                ["ui-select"] = {
                    require("telescope.themes").get_dropdown {
                        -- even more opts
                    }
                }
            }

        }
        require("telescope").load_extension("ui-select")
    end,
}
