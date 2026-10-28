return {
  name = "projects.nvim",
  dir = vim.fn.stdpath("config") .. "/projects.nvim",
  lazy = false, -- the snacks dashboard requires it at startup
  opts = {
    root = "~/Code",
  },
  config = function(_, opts)
    require("projects").setup(opts)
  end,
  keys = {
    { "<leader>pp", function() require("projects").pick() end, desc = "Projects" },
    { "<leader>pn", function() require("projects").create() end, desc = "New Project" },
  },
}
