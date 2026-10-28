local M = {}

function M.setup()

    vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermLeave" }, {
        group = vim.api.nvim_create_augroup("AgentFileReload", { clear = true }),
        callback = function()
            if vim.fn.getcmdwintype() == "" then vim.cmd("silent! checktime") end
        end,
    })

-- Close some filetypes with <q>
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("close_with_q", { clear = true }),
		pattern = {
			"PlenaryTestPopup",
			"help",
			"lspinfo",
			"man",
			"notify",
			"qf",
			"query",
			"spectre_panel",
			"startuptime",
			"tsplayground",
			"neotest-output",
			"checkhealth",
			"neotest-summary",
			"neotest-output-panel",
		},
		callback = function(event)
			vim.bo[event.buf].buflisted = false
			vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
		end,
	})
	
    vim.api.nvim_create_autocmd("TextYankPost", {
        callback = function()
            vim.hl.on_yank({ higroup = 'CurSearch', timeout = 300 })
        end,
    })


end

return M
