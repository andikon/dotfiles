return {
  name = "worktree.nvim",
  dir = vim.fn.stdpath("config") .. "/worktree.nvim",
  dependencies = { "folke/snacks.nvim" },
  cmd = { "Worktree", "WorktreeSwitch", "WorktreeNew" },
  opts = {},
  config = function(_, opts)
    local wt = require("worktree")
    wt.setup(opts)
    vim.api.nvim_create_user_command("Worktree", wt.branches, { desc = "Pick a branch and check it out as a worktree" })
    vim.api.nvim_create_user_command("WorktreeSwitch", wt.worktrees, { desc = "Switch between worktrees" })
    vim.api.nvim_create_user_command("WorktreeNew", wt.create, { desc = "New branch in a new worktree" })
  end,
  keys = {
    { "<leader>wb", function() require("worktree").branches() end, desc = "Branches (checkout as worktree)" },
    { "<leader>ww", function() require("worktree").worktrees() end, desc = "Switch worktree" },
    { "<leader>wn", function() require("worktree").create() end, desc = "New branch worktree" },
  },
}
