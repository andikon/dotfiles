return {
    {
        "shellRaining/hlchunk.nvim", event = { "BufReadPost", "BufNewFile" },
        opts = function()
            local c = require("ui").colors
            return {
                chunk = { enable = true, use_treesitter = false, style = { c.blue, c.red }, duration = 0, delay = 100 },
                line_num = { enable = true, use_treesitter = false, style = c.blue },
                indent = { enable = false }, blank = { enable = false },
            }
        end,
    },
    {
        "nanozuki/tabby.nvim", lazy = false,
        opts = {
            line = function(line)
                return {
                    { "  VIEWS  ", hl = "TabLineFill" },
                    line.tabs().foreach(function(tab)
                        local win = vim.api.nvim_tabpage_get_win(tab.id)
                        local path = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
                        local name = vim.t[tab.id].tab_name or (path ~= "" and vim.fs.basename(path) or "[Untitled]")
                        return { " " .. tab.number() .. " ", name, " ",
                            hl = tab.is_current() and "TabLineSel" or "TabLine", margin = " " }
                    end),
                    line.spacer(), { " Space: shortcuts  ", hl = "TabLineFill" }, hl = "TabLineFill",
                }
            end,
        },
    },
    {
        "rebelot/heirline.nvim", lazy = false,
        config = function()
            -- Native fields retain signs, folds and hlchunk's number highlights.
            require("heirline").setup({ statuscolumn = {
                { provider = "%s" }, { provider = "%=%l" }, { provider = " " }, { provider = "%C" },
            } })
        end,
    },
    {
        "b0o/incline.nvim", event = "VeryLazy",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            window = { padding = 1, margin = { horizontal = 1, vertical = 0 } },
            hide = { cursorline = true },
            ignore = { filetypes = { "snacks_dashboard", "snacks_picker_list", "copilot-chat" }, buftypes = "special" },
            render = function(props)
                local c = require("ui").colors
                local path = vim.api.nvim_buf_get_name(props.buf)
                local name = path == "" and "[Untitled]" or vim.fs.basename(path)
                local icon, color = require("nvim-web-devicons").get_icon_color(name, nil, { default = true })
                return {
                    { icon .. " ", guifg = color }, { name, gui = "bold" },
                    vim.bo[props.buf].modified and { " +", guifg = c.yellow } or "",
                    vim.bo[props.buf].readonly and { " RO", guifg = c.red } or "",
                    guifg = props.focused and c.fg or c.muted, guibg = props.focused and c.raised or c.surface,
                }
            end,
        },
    },
    {
        "MeanderingProgrammer/render-markdown.nvim", ft = "markdown",
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
        opts = {
            heading = { sign = false, border = true },
            code = { sign = false, style = "full", width = "block", min_width = 40, left_pad = 2, right_pad = 2 },
            bullet = { right_pad = 1 }, checkbox = { enabled = true },
        },
        keys = { { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle Markdown rendering" } },
    },
    {
        "folke/which-key.nvim", event = "VeryLazy",
        opts = {
            preset = "modern", delay = 350,
            spec = {
                { "<leader>a", group = "AI / agents", mode = { "n", "v" } },
                { "<leader>b", group = "Buffers" }, { "<leader>c", group = "Code" },
                { "<leader>d", group = "Debug" }, { "<leader>f", group = "Files" },
                { "<leader>g", group = "Git" }, { "<leader>j", group = "Java / IntelliJ" },
                { "<leader>r", group = "Run" },
                { "<leader>s", group = "Search" }, { "<leader>t", group = "Terminals" },
                { "<leader>u", group = "UI" },
                { "<leader><tab>", group = "Tabs / views" },
            },
        },
    },
}
