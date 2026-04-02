local M = {
	"folke/which-key.nvim",
	lazy = false,
}

-----------------------------------------------------------------------
-- WHICH-KEY OVERVIEW
--
-- This file is the single source of truth for global, non-plugin-local
-- keymaps that should appear in which-key.
--
-- General rules:
-- - Leader is <Space> (see `lua/mappings.lua`).
-- - Single-letter leaders are reserved as *namespaces* (groups).
-- - Longer sequences (e.g. <leader>cf) perform specific actions.
--
-- Leader namespaces (groups):
--   <leader>a : Assistant / AI helpers
--   <leader>b : Buffers (open, close, navigate)
--   <leader>c : Code (LSP actions: format, code actions, rename, etc.)
--   <leader>d : Diagnostics (high-level diagnostic helpers)
--   <leader>e : Explorer (file tree / file management)
--   <leader>g : Git (hunks, history, graph, diff)
--   <leader>l : LSP (low-level LSP tools if added in the future)
--   <leader>q : Quickfix (manipulating quickfix lists)
--   <leader>s : Search (all Telescope pickers)
--   <leader>t : Tabs (tab management)
--   <leader>u : UI toggles (inlay hints, visual helpers, etc.)
--   <leader>x : Trouble (diagnostics, lists, symbols, LSP usage)
--   <leader>y : Yank / registers (yank ring, paste history)
--   <leader>k : Toolkit / misc utilities (normal + visual variants)
--
-- Non-leader keys that show in which-key:
--   - Window management: <A-Arrow>, <C-h/j/k/l>, "_", "|"
--   - Indent helpers (visual mode): <, >
--   - Tabs: Q, ]t, [t
--   - Movement / diagnostics: K, gk, ge, gE, [e, ]e, F
--
-- When adding new mappings:
--   1. Choose the most appropriate group above (or add a new one).
--   2. Use a descriptive `desc` so which-key can show meaningful labels.
--   3. Prefer command-form mappings (e.g. "<cmd>Telescope …<cr>") to
--      avoid `require`-ing plugins before they are loaded by lazy.nvim.
-----------------------------------------------------------------------

-- local function toggle_locationlist()
-- 	local win = vim.api.nvim_get_current_win()
-- 	local qf_winid = vim.fn.getloclist(win, { winid = 0 }).winid
-- 	local action = qf_winid > 0 and "lclose" or "lopen"
-- 	vim.cmd(action)
-- end
--
-- local function toggle_quicklist()
-- 	local qf_winid = vim.fn.getqflist({ winid = 0 }).winid
-- 	local action = qf_winid > 0 and "cclose" or "copen"
-- 	vim.cmd("botright " .. action)
-- end

local basic_mappings = {
	-------------------------------------------------------------------
	-- GROUP DEFINITIONS (just namespaces, no direct actions)
	-------------------------------------------------------------------
	{ "<leader>a", group = "Assistant" }, -- AI / assistant actions
	{ "<leader>b", group = "Buffers" }, -- buffer management
	{ "<leader>c", group = "Code" }, -- LSP / code manipulation
	{ "<leader>d", group = "Diagnostics" }, -- high-level diagnostics
	{ "<leader>e", group = "Explorer" }, -- file explorer / tree
	{ "<leader>g", group = "Git" }, -- Git-related actions
	{ "<leader>l", group = "LSP" }, -- raw LSP tools (if needed)
	{ "<leader>q", group = "Quickfix" }, -- quickfix helpers
	{ "<leader>s", group = "Search" }, -- Telescope / search
	{ "<leader>t", group = "Tabs" }, -- tab management
	{ "<leader>u", group = "UI" }, -- UI toggles (inlay hints, etc.)
	{ "<leader>x", group = "Trouble" }, -- Trouble.nvim diagnostics UI
	{ "<leader>y", group = "Yank" }, -- yank history / registers
	{ "<leader>k", group = "Toolkit" }, -- misc tools (normal mode)
	{ "<leader>k", group = "Toolkit", mode = "v" }, -- misc tools (visual)

	-------------------------------------------------------------------
	-- WINDOW MANAGEMENT
	-------------------------------------------------------------------
	-- Resize current window using Alt + Arrow keys
	{ "<A-Up>", "<cmd>resize -1<cr>", desc = "Resize up" },
	{ "<A-Down>", "<cmd>resize +1<cr>", desc = "Resize down" },
	{ "<A-Left>", "<cmd>vertical resize -1<cr>", desc = "Resize left" },
	{ "<A-Right>", "<cmd>vertical resize +1<cr>", desc = "Resize right" },

	-- Navigate between splits with Ctrl + h/j/k/l (tmux-style)
	{ "<C-k>", "<cmd>wincmd k<cr>", desc = "Window up" },
	{ "<C-j>", "<cmd>wincmd j<cr>", desc = "Window down" },
	{ "<C-h>", "<cmd>wincmd h<cr>", desc = "Window left" },
	{ "<C-l>", "<cmd>wincmd l<cr>", desc = "Window right" },

	-- Create new splits with single keys (normal mode)
	{ "_", "<cmd>split<cr>", desc = "Horizontal split" },
	{ "|", "<cmd>vsplit<cr>", desc = "Vertical split" },

	-------------------------------------------------------------------
	-- INDENTATION HELPERS (VISUAL MODE)
	-------------------------------------------------------------------
	-- Stay in visual mode when indenting left/right
	{ "<", "<gv", mode = "v", desc = "Indent left" },
	{ ">", ">gv", mode = "v", desc = "Indent right" },

	-------------------------------------------------------------------
	-- TABS
	-------------------------------------------------------------------
	{ "Q", "<cmd>tabclose<cr>", desc = "Quit tab" }, -- close current tab
	{ "]t", "<cmd>tabnext<cr>", desc = "Next tab" }, -- next tab
	{ "[t", "<cmd>tabprev<cr>", desc = "Prev tab" }, -- previous tab
	{ "<leader>tn", "<cmd>tabnew<cr>", desc = "New" }, -- new empty tab
	{ "<leader>tc", "<cmd>tabclose<cr>", desc = "Close current" }, -- close current tab

	-------------------------------------------------------------------
	-- TEXT MANIPULATION
	-------------------------------------------------------------------
	-- Move selected block up/down in visual mode
	{ "J", "<cmd>move '>+1<cr>gv-gv", mode = "x", desc = "Move block down" },
	{ "K", "<cmd>move '<-2<cr>gv-gv", mode = "x", desc = "Move block up" },

	-- Avoid polluting registers when using `c` / `C`
	{ "c", '"_c', desc = "Change (no register)" },
	{ "C", '"_C', desc = "Change to end of line (no register)" },

	-- Sensible clipboard paste in insert mode (Ctrl-v)
	{ "<C-v>", "<C-r>*", mode = "i", desc = "Clipboard paste" },

	-- Make `Y` behave like `D`/`C` (yank to end of line)
	{ "Y", "y$", desc = "Yank to end of line" },

	-------------------------------------------------------------------
	-- LSP CORE MAPPINGS (NON-LEADER)
	-------------------------------------------------------------------
	{ "K", "<cmd>lua vim.lsp.buf.hover()<cr>", desc = "Hover" }, -- show documentation
	-- Jump / reference mappings are primarily provided via Trouble:
	--   ga, gd, gD, gi, gr, gt, gI, gO (see `plugins/trouble.lua`)
	{ "gk", "<cmd>lua vim.lsp.buf.signature_help()<cr>", desc = "Signature help" },
	{ "ge", "<cmd>lua vim.diagnostic.open_float()<cr>", desc = "Float diagnostics" },
	{
		"gE",
		'<cmd>lua vim.diagnostic.open_float({ scope = "cursor" })<cr>',
		desc = "Float diagnostics (cursor)",
	},
	{ "[e", "<cmd>lua vim.diagnostic.goto_prev()<cr>", desc = "Prev. diagnostic" },
	{ "]e", "<cmd>lua vim.diagnostic.goto_next()<cr>", desc = "Next diagnostic" },

	-- Leader-based code actions (Code group: <leader>c…)
	{ "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, desc = "Format" },
	{ "<leader>ca", vim.lsp.buf.code_action, desc = "Code action" },
	{ "<leader>cr", vim.lsp.buf.rename, desc = "Rename symbol" },

	-------------------------------------------------------------------
	-- UI TOGGLES (UI group: <leader>u…)
	-------------------------------------------------------------------
	-- Toggle inline LSP inlay hints globally
	{
		"<leader>uh",
		function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(), {
				bufnr = nil, -- all buffers
			})
		end,
		desc = "Toggle inline hints",
	},

	-------------------------------------------------------------------
	-- QUICKFIX & LOCATION LIST HELPERS (capital Q/L namespace)
	-------------------------------------------------------------------
	-- These are advanced commands to manipulate quickfix / loclist.
	-- They deliberately do NOT use <leader>q / <leader>l so that those
	-- prefixes can remain available as group names.
	{ "<leader>Q", group = "Quickfix list" },
	{ "<leader>L", group = "Location list" },
	{ "<leader>Qd", ":cdo ", desc = "Do" }, -- :cdo {cmd}
	{ "<leader>Ld", ":ldo ", desc = "Do" }, -- :ldo {cmd}
	{ "<leader>QD", ":cfdo ", desc = "Do (file)" }, -- :cfdo {cmd}
	{ "<leader>LD", ":lfdo ", desc = "Do (file)" }, -- :lfdo {cmd}
	{ "<leader>Qe", ":cgete ", desc = "Create from expression" }, -- :cgete {expr}
	{ "<leader>Le", ":lgete ", desc = "Create from expression" }, -- :lgete {expr}
	{ "<leader>Qf", ":cfilter /", desc = "Filter" }, -- :cfilter /pattern
	{ "<leader>Lf", ":lfilter /", desc = "Filter" }, -- :lfilter /pattern
	{ "<leader>Ql", ":cf ", desc = "Load file" }, -- :cf {file}
	{ "<leader>Ll", ":lf ", desc = "Load file" }, -- :lf {file}
	{ "<leader>Qn", "<cmd>cnew<cr>", desc = "Next list" }, -- open new quickfix list
	{ "<leader>Ln", "<cmd>lnew<cr>", desc = "Next list" }, -- open new location list
	{ "<leader>Qp", "<cmd>col<cr>", desc = "Previous list" }, -- previous quickfix list
	{ "<leader>Lp", "<cmd>lol<cr>", desc = "Previous list" }, -- previous location list

	-------------------------------------------------------------------
	-- FOLDING
	-------------------------------------------------------------------
	{ "F", "za", desc = "Toggle fold" }, -- toggle fold under cursor
}

function M.config()
	local icons = require("icons")

	require("which-key").setup({
		preset = "helix",
		icons = {
			breadcrumb = icons.arrow.double_right_short, -- symbol used in the command line area that shows your active key combo
			separator = icons.bar.vertical_center_thin, -- symbol used between a key and it's label
			group = icons.folder.open .. " ", -- symbol prepended to a group
		},
		win = {
			border = "none", -- none, single, double, shadow
			title = true, -- does not matter unless boder != "none"
			title_pos = "center", -- does not matter unless boder != "none"
			padding = { 2, 6 }, -- extra window padding [top/bottom, right/left]
		},
		show_help = true, -- show help message on the command line when the popup is visible
		show_keys = true, -- show the currently pressed key and its label as a message in the command line
	})

	require("mappings").register(basic_mappings)	
end

return M
