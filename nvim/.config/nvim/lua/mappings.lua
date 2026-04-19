
local M = {}

function M.setup()
    vim.g.mapleader = " "
    local map = vim.keymap.set

    -------------------------------------------------------------------
    -- SPLIT NAVIGATION (tmux-style)
    -------------------------------------------------------------------
    map("n", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Window up" })
    map("n", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Window down" })
    map("n", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Window left" })
    map("n", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Window right" })

    -- Create splits
    map("n", "_", "<cmd>split<cr>", { desc = "Horizontal split" })
    map("n", "|", "<cmd>vsplit<cr>", { desc = "Vertical split" })

    -------------------------------------------------------------------
    -- INDENTATION (VISUAL MODE)
    -------------------------------------------------------------------
    map("v", "<", "<gv", { desc = "Indent left" })
    map("v", ">", ">gv", { desc = "Indent right" })

    -------------------------------------------------------------------
    -- TABS
    -------------------------------------------------------------------
    map("n", "Q", "<cmd>tabclose<cr>", { desc = "Quit tab" })
    map("n", "]t", "<cmd>tabnext<cr>", { desc = "Next tab" })
    map("n", "[t", "<cmd>tabprev<cr>", { desc = "Prev tab" })
    map("n", "<leader>tn", "<cmd>tabnew<cr>", { desc = "New tab" })
    map("n", "<leader>tc", "<cmd>tabclose<cr>", { desc = "Close current tab" })

    -------------------------------------------------------------------
    -- TEXT MANIPULATION
    -------------------------------------------------------------------
    -- Move selected block
    map("x", "J", "<cmd>move '>+1<cr>gv-gv", { desc = "Move block down" })
    map("x", "K", "<cmd>move '<-2<cr>gv-gv", { desc = "Move block up" })

    -- Don't pollute registers
    map("n", "c", '"_c', { desc = "Change (no register)" })
    map("n", "C", '"_C', { desc = "Change to EOL (no register)" })

    -- Clipboard paste in insert mode
    map("i", "<C-v>", "<C-r>*", { desc = "Paste from clipboard" })

    -- Yank to end of line
    map("n", "Y", "y$", { desc = "Yank to end of line" })

    -------------------------------------------------------------------
    -- LSP
    -------------------------------------------------------------------
    map("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
    map("n", "gk", vim.lsp.buf.signature_help, { desc = "Signature help" })
    map("n", "ge", vim.diagnostic.open_float, { desc = "Diagnostics float" })
    map("n", "gE", function()
        vim.diagnostic.open_float({ scope = "cursor" })
    end, { desc = "Diagnostics float (cursor)" })

    map("n", "[e", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
    map("n", "]e", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

    -- Leader mappings
    map("n", "<leader>cf", function()
        vim.lsp.buf.format({ async = true })
    end, { desc = "Format" })

    map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
    map("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename symbol" })
end

return M
