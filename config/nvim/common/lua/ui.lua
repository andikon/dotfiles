local M = {}

M.colors = {
    bg = "#282828", surface = "#1b1b1b", raised = "#45403d",
    fg = "#d4be98", muted = "#928374", blue = "#7daea3",
    green = "#a9b665", yellow = "#d8a657", red = "#ea6962", purple = "#d3869b",
}

function M.setup()
    local c = M.colors
    local function highlights()
        for name, value in pairs({
            FloatBorder = { fg = c.raised, bg = c.bg },
            WinSeparator = { fg = c.raised },
            NormalFloat = { bg = c.bg },
            CursorLineNr = { fg = c.blue, bold = true },
            LineNr = { fg = "#7c6f64" },
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
            SnacksIndent = { fg = "#32302f" },
        }) do vim.api.nvim_set_hl(0, name, value) end
    end
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("DotfilesUI", { clear = true }), callback = highlights,
    })
    highlights()
end

return M
