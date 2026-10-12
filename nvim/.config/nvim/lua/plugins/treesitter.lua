return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                -- No C compiler on this machine, so parsers can't be built.
                ensure_installed = {},
                sync_install = false,
                auto_install = false,
                highlight = {
                    enable = true
                },
            })
        end
    },
    {
        "norcalli/nvim-colorizer.lua",
        config = function()
            require 'colorizer'.setup()
        end
    }
}
