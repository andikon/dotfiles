return {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "CopilotChat", "CopilotChatToggle", "CopilotChatReset", "CopilotChatStop", "CopilotChatModels", "CopilotChatPrompts", "CopilotChatSave", "CopilotChatLoad" },
    opts = {
        window = { layout = "vertical", width = 0.38 },
        auto_insert_mode = true,
        sticky = { "#buffer:active" },
        prompts = {
            Outline = { prompt = "Outline a minimal implementation plan for the selected code or active file. Identify interfaces, invariants, edge cases and tests. Do not modify code yet." },
            Review = { prompt = "Review this code for correctness, concurrency, security and maintainability. Prioritize concrete bugs and missing tests; cite the relevant code." },
            Tests = { prompt = "Propose focused tests for this code using the project's existing test style. Cover observable behavior and important edge cases." },
            Explain = { prompt = "Explain this code's responsibilities, dependencies and control flow concisely. Point out assumptions that matter when changing it." },
        },
    },
    keys = {
        { "<leader>aa", "<cmd>CopilotChatToggle<cr>", mode = { "n", "v" }, desc = "Toggle Copilot Chat" },
        { "<leader>ao", "<cmd>CopilotChatOutline<cr>", mode = { "n", "v" }, desc = "AI: outline a change" },
        { "<leader>ar", "<cmd>CopilotChatReview<cr>", mode = { "n", "v" }, desc = "AI: review code" },
        { "<leader>at", "<cmd>CopilotChatTests<cr>", mode = { "n", "v" }, desc = "AI: propose tests" },
        { "<leader>ae", "<cmd>CopilotChatExplain<cr>", mode = { "n", "v" }, desc = "AI: explain code" },
        { "<leader>am", "<cmd>CopilotChatModels<cr>", desc = "Choose Copilot model" },
        { "<leader>ap", "<cmd>CopilotChatPrompts<cr>", mode = { "n", "v" }, desc = "Choose Copilot prompt" },
        { "<leader>ax", "<cmd>CopilotChatStop<cr>", desc = "Stop Copilot response" },
        { "<leader>aR", "<cmd>CopilotChatReset<cr>", desc = "Reset Copilot conversation" },
    },
}
