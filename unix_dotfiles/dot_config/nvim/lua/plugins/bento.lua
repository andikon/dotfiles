local M = {
	"serhez/bento.nvim",
	event = "VeryLazy",
}

function M.config()
	require("bento").setup({
		max_open_buffers = 10,
		map_last_accessed = false,
	})
end

return M