return {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        local c = require("ui").colors
        local function servers()
            local names = {}
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do names[#names + 1] = client.name end
            return table.concat(names, ", ")
        end
        require("lualine").setup({
            options = {
                globalstatus = true, component_separators = "", section_separators = "",
                theme = {
                    normal = { a = { fg = c.bg, bg = c.blue, gui = "bold" }, b = { fg = c.fg, bg = c.raised }, c = { fg = c.muted, bg = c.bg } },
                    insert = { a = { fg = c.bg, bg = c.green, gui = "bold" } },
                    visual = { a = { fg = c.bg, bg = c.purple, gui = "bold" } },
                    replace = { a = { fg = c.bg, bg = c.red, gui = "bold" } },
                    command = { a = { fg = c.bg, bg = c.yellow, gui = "bold" } },
                    inactive = { a = { fg = c.muted, bg = c.bg }, b = { fg = c.muted, bg = c.bg }, c = { fg = c.muted, bg = c.bg } },
                },
            },
            sections = {
                lualine_a = { { "mode", fmt = function(s) return s:sub(1, 1) end } },
                lualine_b = { { function() return vim.fs.basename(vim.fn.getcwd()) end, icon = "󰉋" }, "branch", "diff" },
                lualine_c = { { "filename", path = 1 }, { "diagnostics", symbols = { error = "E:", warn = "W:", info = "I:", hint = "H:" } } },
                lualine_x = {
                    { function() return require("agents").status() end, color = { fg = c.green } },
                    { function() return vim.lsp.status() end, cond = function() return vim.o.columns > 130 end },
                    { servers, color = { fg = c.blue } }, "searchcount",
                },
                lualine_y = { "filetype", "location" }, lualine_z = { "progress" },
            },
            extensions = { "quickfix", "lazy", "mason" },
        })
    end,
}
