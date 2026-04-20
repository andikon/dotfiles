local M = {
	"HiPhish/rainbow-delimiters.nvim",
	lazy = false,
	enabled = true,
}

function M.config()
	require("rainbow-delimiters.setup").setup()
end

return M
