local M = {
	"Bekaboo/dropbar.nvim",
	lazy = false,
	cond = not vim.g.started_by_firenvim,
}

function M.config()
	
	local utils = require("dropbar.utils")
	local sources = require("dropbar.sources")

	local icons = require("icons")

	local active_win = vim.api.nvim_get_current_win()
	vim.api.nvim_create_autocmd({ "WinEnter", "TermEnter" }, {
		callback = function()
			active_win = vim.api.nvim_get_current_win()
			require("dropbar.utils.bar").exec("update")
		end,
	})

	-- This function wraps a source and hides it if the window is inactive
	local function content_source(source)
		local get_symbols = function(buf, win, cursor)
			if win ~= active_win then
				return {}
			end

			if source.get_symbols then
				return source.get_symbols(buf, win, cursor)
			end

			return {}
		end

		return setmetatable({}, {
			__index = function(_, key)
				if key == "get_symbols" then
					return get_symbols
				else
					return source[key]
				end
			end,
		})
	end

	require("dropbar").setup({
		sources = {
			path = {
				modified = function(sym)
					if sym == nil then
						return sym
					end
					return sym:merge({
						name_hl = "DiagnosticSignWarn",
					})
				end,
				relative_to = function(_, win)
					if vim.api.nvim_get_current_win() ~= win then
						-- Workaround for Vim:E5002: Cannot find window number
						local ok, fullpath = pcall(vim.fn.getcwd, win)
						return ok and fullpath or vim.fn.getcwd()
					end

					local fullpath = vim.api.nvim_buf_get_name(0)
					local filename = vim.fn.fnamemodify(fullpath, ":t")
					return fullpath:sub(0, #fullpath - #filename)
				end,
			},
		},
		icons = {
			ui = {
				bar = {
					separator = " " .. icons.arrow.right_tall .. " ",
					extends = "…",
				},
				menu = {
					separator = " ",
					indicator = icons.arrow.right_short,
				},
			},
		},
		bar = {
			update_events = {
				win = { "CursorMoved", "CursorMovedI", "WinResized" },
			},

			padding = {
				left = 1,
				right = 1,
			},
			truncate = true,
			sources = function(buf, _)
				if vim.bo[buf].buftype == "terminal" then
					return { sources.terminal }
				end

				if vim.bo[buf].ft == "markdown" then
					return {
						sources.path,
						content_source(sources.markdown),
					}
				end

				if
					vim.bo[buf].ft == "typescriptreact"
					or vim.bo[buf].ft == "javascriptreact"
					or vim.bo[buf].ft == "vue"
				then
					return {
						sources.path,
						content_source(utils.source.fallback({
							sources.treesitter,
							sources.lsp,
						})),
					}
				end

				-- Default view
				return {
					sources.path,
					content_source(utils.source.fallback({
						sources.lsp,
						sources.treesitter,
					})),
				}
			end,
		},
		menu = {
			entry = {
				padding = {
					left = 1,
					right = 1,
				},
			},
			-- When on, preview the symbol under the cursor on CursorMoved
			preview = true,
			-- When on, automatically set the cursor to the closest previous/next
			-- clickable component in the direction of cursor movement on CursorMoved
			quick_navigation = true,
			win_configs = {
				border = "none",
				style = "minimal",
			},
		},
	})
end

return M