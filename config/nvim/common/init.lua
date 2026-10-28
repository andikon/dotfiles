require("settings").setup()
require("ui").setup()
require("mappings").setup()
require("plugin-loader").setup()
require("autocommands").setup()

if vim.g.neovide then
	require("neovide").setup()
end

vim.cmd.colorscheme "doom-one"

