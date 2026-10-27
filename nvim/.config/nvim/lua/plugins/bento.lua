local M = {
	"serhez/bento.nvim",
	event = "VeryLazy",
}

function M.config()
	require("bento").setup({
		-- Other open project tabs must retain their buffers.
		max_open_buffers = nil,
		main_keymap = "<leader>bb",
		map_last_accessed = false,
	})
end

return M
