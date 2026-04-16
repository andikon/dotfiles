local M = {
  "serhez/teide.nvim",
  lazy = false,
  priority = 1000,
  opts = {},
}

function M.config()
	local teide = require("teide")
	teide.setup({
        style = "darker",
	})
	teide.load()
end

return M
