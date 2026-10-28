local M = {
	"serhez/bento.nvim",
	event = "VeryLazy",
}

function M.config()
	require("bento").setup({
		-- Keep buffers available across editor views.
		max_open_buffers = nil,
		main_keymap = "<leader>bb",
		map_last_accessed = false,
	})
end

return M
