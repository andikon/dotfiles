local M = {}

---@class ListItem
---@field value string
---@field visual string
---@field isMarked boolean

local function update_lines(buf, items)
    local lines = {}
    for i, item in ipairs(items) do
        local mark = item.isMarked and "[x]" or "[ ]"
        table.insert(lines, i .. "\t" .. mark .. "\t" .. item.visual)
    end
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

---@param items ListItem[]
---@param title string
---@param on_done fun(marked_items: ListItem[])
M.create_multiselect = function(items, title, on_done)
    title = title or "Title"

    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.4)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    update_lines(buf, items)
    local footer_text = "Enter: toggle mark | Ctrl+Enter: finish | q: quit"
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        width = width,
        height = height,
        row = row,
        col = col,
        title = { { title, "FloatBorder" } },
        title_pos = 'center',
        footer = { { footer_text, "FloatBorder" } },
        footer_pos = 'right',
        border = 'rounded',
    })

    -- Toggle item mark
    local function toggle_mark()
        local line = vim.api.nvim_win_get_cursor(win)[1]
        local item = items[line]
        if item then
            item.isMarked = not item.isMarked
            update_lines(buf, items)
        end
    end

    -- Close window and return marked items via callback
    local function close_and_return()
        vim.api.nvim_win_close(win, true)
        local marked = {}
        for _, item in ipairs(items) do
            if item.isMarked then table.insert(marked, item) end
        end
        if on_done then
            on_done(marked)
        end
    end

    -- Keymaps
    vim.keymap.set('n', '<CR>', toggle_mark, { buffer = buf, noremap = true })
    vim.keymap.set('n', '<C-CR>', close_and_return, { buffer = buf, noremap = true })
    vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(win, true) end, { buffer = buf, noremap = true })
end

---@param opts table
---@param opts.on_done fun(test: string)
function M.floating_input(opts)
    opts = opts or {}
    local on_done = opts.on_done or function(_) end
    local width = opts.width or 50
    local height = 1
    local footer_text = "Enter: submit | Esc: cancel"

    -- Create a scratch buffer
    local buf = vim.api.nvim_create_buf(false, true)

    -- Calculate centered window position
    local ui = vim.api.nvim_list_uis()[1]
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)

    -- Open floating window
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = opts.title,
        footer = { { footer_text, "FloatBorder" } },
        footer_pos = "right"
    })

    -- ENTER in insert mode: finish
    vim.keymap.set("i", "<CR>", function()
        local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
        vim.api.nvim_win_close(win, true)
        vim.cmd("stopinsert")
        on_done(line)
    end, { buffer = buf })

    -- Typing <Esc> in insert mode closes the window
    vim.keymap.set("i", "<Esc>", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf })

    -- Start in insert mode and stay there
    vim.cmd("startinsert")
end

return M
