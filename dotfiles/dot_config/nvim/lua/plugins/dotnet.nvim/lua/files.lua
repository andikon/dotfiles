local utils = require('utils')
local M = {}

M.insert_csharp_file_starter_into_current_buffer = function(is_interface)
    local file_path = vim.api.nvim_buf_get_name(0)
    local type_keyword = is_interface and "interface" or "class"
    local file_information  = utils.get_namespace(file_path)

    if file_information == nil then
        return
    end

    local csharp_starter_text = {
        "namespace " .. file_information.namespace .. ";",
        "",
        "public " .. type_keyword .. " " .. file_information.type_name,
        "{",
        "",
        "}"
    }

    vim.api.nvim_buf_set_lines(0, 0, 1, false, csharp_starter_text)
    vim.api.nvim_command("write");
end

return M
