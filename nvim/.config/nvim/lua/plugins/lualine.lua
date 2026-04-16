local icons = require("icons")

local M = {
    "nvim-lualine/lualine.nvim",
    lazy = false,
}

function M.config()
    -- =========================================================================
    -- COLOR SCHEME BLOCK
    -- =========================================================================


    -- =========================================================================
    -- HELPER FUNCTIONS
    -- =========================================================================
    local function pretty_dirpath()
        local path = vim.fn.expand("%:p")
        if path == "" then return "" end
        local cwd = vim.fn.getcwd()

        if path:find(cwd, 1, true) == 1 then
            path = path:sub(#cwd + 2)
        end

        local sep = package.config:sub(1, 1)
        local parts = vim.split(path, "[\\/]")
        table.remove(parts)
        if #parts > 3 then
            parts = { parts[1], "…", parts[#parts - 1], parts[#parts] }
        end
        return #parts > 0 and (table.concat(parts, sep)) or ""
    end

    local function get_words()
        local ft = vim.bo.filetype
        if ft == "md" or ft == "text" or ft == "markdown" then
            local count = vim.fn.wordcount()
            local wc = count.visual_words or count.words
            return " " .. " " .. tostring(wc) .. " "
        end
        return ""
    end

    local function fileinfo()
        local dir = pretty_dirpath()
        local name = vim.fn.expand("%:t")
        if name == "" then name = "[No Name]" end
        return dir .. "/" .. "%#Bold#" .. name .. "%#lualine_c_normal#" .. " %m%r%h%w "
    end

    local function scrollbar()
        local sbar_chars = { "󰋙", "󰫃", "󰫄", "󰫅", "󰫆", "󰫇", "󰫈" }
        local cur_line = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.api.nvim_buf_line_count(0)
        local i = math.floor((cur_line - 1) / (lines > 0 and lines or 1) * #sbar_chars) + 1
        return sbar_chars[i] or sbar_chars[1]
    end

local colors = {
    bg      = '#171b1f', -- Main background
    fg      = '#cfc9c2', -- Main text
    section = '#3b4261', -- Background for Branch/Location
    blue    = '#55bce9', -- Normal mode
    green   = '#34eb9a', -- Insert mode
    purple  = '#bb9af7', -- Visual mode
    red     = '#ed728b', -- Replace/Macro mode
    yellow  = '#e8d371', -- Command mode/Words
}
    -- =========================================================================
    -- LUALINE SETUP
    -- =========================================================================
    require('lualine').setup({
        options = {
            section_separators = '',
            component_separators = '',
            globalstatus = true,
            theme = {
                normal = {
                    a = { fg = colors.bg, bg = colors.blue, gui = 'bold' },
                    b = { fg = colors.blue, bg = colors.section },
                    c = { fg = colors.fg, bg = colors.bg },
                },
                insert = {
                    a = { fg = colors.bg, bg = colors.green, gui = 'bold' },
                },
                visual = {
                    a = { fg = colors.bg, bg = colors.purple, gui = 'bold' },
                },
                replace = {
                    a = { fg = colors.bg, bg = colors.red, gui = 'bold' },
                },
                command = {
                    a = { fg = colors.bg, bg = colors.yellow, gui = 'bold' },
                },
                inactive = {
                    a = { fg = colors.fg, bg = colors.bg },
                    b = { fg = colors.fg, bg = colors.bg },
                    c = { fg = colors.fg, bg = colors.bg },
                },
            },
        },
        sections = {
            lualine_a = {
                {
                    "mode",
                    fmt = function(str)
                        local m = vim.api.nvim_get_mode().mode
                        return m == "\22" and "C-V" or str:sub(1, 1)
                    end,
                },
            },
            lualine_b = {
                { "branch", icon = "" },
                "diff",
            },
            lualine_c = {
                { fileinfo, padding = { left = 1, right = 0 } },
            },
            lualine_x = {
                { function() return require("lsp-progress").progress() end },
                "searchcount",
                {
                    function()
                        local msg = ""
                        local buf_ft = vim.api.nvim_get_option_value('filetype', { buf = 0 })
                        local clients = vim.lsp.get_clients({ bufnr = 0 })
                        if next(clients) == nil then return msg end
                        for _, client in ipairs(clients) do
                            if client.name ~= "null-ls" then return "󰄭  " .. client.name end
                        end
                        return msg
                    end,
                },
            },
            lualine_y = {
                {
                    get_words,
                    color = { fg = colors.darkblue, bg = colors.cyan },
                },
                "location",
                { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
                { function() return vim.bo.filetype:upper() end, padding = { left = 0, right = 1 } },
            },
            lualine_z = {
                {
                    "progress",
                    fmt = function()
                        local lines = vim.api.nvim_buf_line_count(0)
                        return lines .. " " .. scrollbar()
                    end,
                },
            },
        },
    })
end

return M
