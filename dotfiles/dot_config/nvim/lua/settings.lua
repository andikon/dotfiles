local M = {}

function M.setup()
	-- settings
vim.opt.cursorcolumn = false
vim.opt.scrolloff = 8
vim.opt.showmode = false
vim.o.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.clipboard = "unnamedplus" -- allows neovim to access the system clipboard
vim.opt.confirm = true -- asks for confirmation instead of giving errors (e.g., on quitting without saving)
vim.opt.backup = false -- creates a backup file
vim.opt.cmdheight = 2 -- space in the neovim command line for displaying messages
vim.opt.fileencoding = "utf-8" -- the encoding written to a file
vim.opt.showtabline = 0 -- always show tabs
vim.opt.smartcase = true -- smart case
vim.opt.smartindent = true -- makes indenting smarter
vim.opt.autoindent = true -- makes indenting automatic
vim.opt.splitbelow = true -- force all horizontal splits to go below current window
vim.opt.splitright = true -- force all vertical splits to go to the right of current window
vim.opt.swapfile = false -- creates a swapfile
vim.opt.termguicolors = true -- set term gui colors (most terminals support this)
vim.opt.timeoutlen = 500 -- time to wait for a mapped sequence to complete (in milliseconds)
vim.opt.title = true -- set the title of window to the value of the titlestring
vim.opt.titlestring = "%<%F  %l:%L" -- what the title of the window will be set to
vim.opt.undofile = true -- enable persisten undo
vim.opt.updatetime = 300 -- faster completion
vim.opt.writebackup = false -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
vim.opt.expandtab = true -- convert tabs to spaces
vim.opt.shiftwidth = 4 -- the number of spaces inserted for each indentation
vim.opt.shortmess:append("c") -- don't pass messages to |ins-completion-menu|
vim.opt.tabstop = 4 -- insert 4 spaces for a tab
vim.opt.cursorline = true -- highlight the current line
vim.opt.number = true -- set numbered lines
vim.opt.relativenumber = false -- set relative numbered lines
vim.opt.signcolumn = "yes" -- always show the sign column, otherwise it would shift the text each time
vim.opt.wrap = true -- display lines as one long line
vim.opt.laststatus = 3 -- display one statusline for all windows
vim.opt.guicursor = "i:ver100-blinkoff700-blinkon700"
vim.opt.splitkeep = "screen"
vim.opt.pumblend = 10 -- popups transparency
vim.opt.pumheight = 10 -- maximum number of entries in a popup
vim.opt.winblend = 10 -- floating windows transparency
vim.opt.winborder = "none" -- default window border style
vim.opt.termsync = false -- don't sync neovim with terminal emulator

end

return M
