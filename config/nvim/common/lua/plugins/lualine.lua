return {
    "nvim-lualine/lualine.nvim",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        local c = require("ui").colors
        local slant = { left = "", right = "" }
        local function wider_than(columns)
            return function() return vim.o.columns > columns end
        end
        local show_file_details = wider_than(50)
        local medium = wider_than(100)
        local wide = wider_than(150)

        local function servers()
            local names = {}
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do names[#names + 1] = client.name end
            return table.concat(names, ", ")
        end

        local function other_modified_buffers()
            local current = vim.api.nvim_get_current_buf()
            local count = 0
            for _, buffer in ipairs(vim.fn.getbufinfo({ buflisted = 1, bufloaded = 1, bufmodified = 1 })) do
                if buffer.bufnr ~= current and vim.bo[buffer.bufnr].buftype == "" then count = count + 1 end
            end
            return count > 0 and ("+%d"):format(count) or ""
        end

        local function diagnostic_block(severity, icon, background)
            return {
                "diagnostics",
                sources = { "nvim_diagnostic" },
                sections = { severity },
                symbols = { [severity] = icon .. " " },
                colored = false,
                color = { fg = c.bg, bg = background, gui = "bold" },
                separator = { left = slant.right },
            }
        end

        require("lualine").setup({
            options = {
                globalstatus = true, component_separators = "", section_separators = slant,
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
                lualine_a = { { "mode", fmt = function(mode) return wide() and mode or mode:sub(1, 1) end } },
                lualine_b = {
                    { function() return (vim.t.tab_name or ""):gsub("%%", "%%%%") end },
                    { "branch", cond = medium },
                    { "diff", cond = wide },
                },
                lualine_c = {
                    {
                        "filename",
                        path = 1,
                        shorting_target = 80,
                        newfile_status = true,
                        color = function() return { fg = vim.bo.modified and c.red or c.fg } end,
                    },
                    { other_modified_buffers, color = { fg = c.red } },
                },
                lualine_x = {
                    {
                        "searchcount",
                        cond = wide,
                        fmt = function(count)
                            if count == "" then return "" end
                            local pattern = vim.fn.strtrans(vim.fn.getreg("/"))
                            local label = vim.fn.strcharpart(pattern, 0, 24)
                            if label ~= pattern then label = label .. "…" end
                            return label:gsub("%%", "%%%%") .. " " .. count
                        end,
                    },
                    { function() return require("agents").status() end, color = { fg = c.green } },
                    { vim.lsp.status, cond = wider_than(130) },
                    { servers, color = { fg = c.blue }, cond = medium },
                },
                lualine_y = {
                    { "filetype", cond = show_file_details },
                    {
                        function()
                            local cwd = vim.fn.getcwd()
                            return vim.fs.basename(cwd) or cwd
                        end,
                        icon = "󰉋",
                        cond = wider_than(200),
                    },
                },
                lualine_z = {
                    { "location", icon = "", cond = show_file_details },
                    { "progress", cond = wide },
                    diagnostic_block("error", "", c.red),
                    diagnostic_block("warn", "", c.yellow),
                },
            },
            extensions = { "quickfix", "lazy", "mason" },
        })
    end,
}
