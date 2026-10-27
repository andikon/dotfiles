local M = {}

M.colors = {
    bg = "#282c34", surface = "#21242b", raised = "#3f444a",
    fg = "#bbc2cf", muted = "#73797e", blue = "#51afef",
    green = "#98be65", yellow = "#ecbe7b", red = "#ff6c6b", purple = "#c678dd",
}

function M.setup()
    local c = M.colors
    local function highlights()
        for name, value in pairs({
            TabLineFill = { bg = c.bg, fg = c.muted },
            TabLine = { bg = c.surface, fg = c.muted },
            TabLineSel = { bg = c.raised, fg = c.blue, bold = true },
            FloatBorder = { fg = c.raised, bg = c.bg },
            WinSeparator = { fg = c.raised },
            NormalFloat = { bg = c.bg },
            CursorLineNr = { fg = c.blue, bold = true },
            LineNr = { fg = "#5b6268" },
            BerserkBrand = { fg = c.red, bold = true },
            BerserkTitle = { fg = "#dfdfdf", bold = true },
            BerserkSubtle = { fg = c.muted },
            SnacksDashboardHeader = { fg = c.red },
            SnacksDashboardTitle = { fg = c.blue, bold = true },
            SnacksDashboardKey = { fg = c.blue },
            SnacksDashboardDesc = { fg = c.fg },
            SnacksDashboardIcon = { fg = c.muted },
            SnacksDashboardFooter = { fg = c.muted },
            SnacksDashboardSpecial = { fg = c.purple },
            SnacksIndent = { fg = "#353a42" },
        }) do vim.api.nvim_set_hl(0, name, value) end
    end
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("DotfilesUI", { clear = true }), callback = highlights,
    })
    highlights()
end

return M
