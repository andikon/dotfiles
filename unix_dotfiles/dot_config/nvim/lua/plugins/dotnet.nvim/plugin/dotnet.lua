if vim.g.loaded_dotnet_nvim then
    return
end

local group = vim.api.nvim_create_augroup("dotnet.nvim", { clear = true })

-- TODO add config to enable or disable automatic file creation
vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    pattern = '*.cs',
    callback = function()
        require("files").insert_csharp_file_starter_into_current_buffer ()
    end
})

---Fixes a bug with roslyn lsp where it wouldnt recognise newly created files
vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.cs",
    callback = function()
        local client = vim.lsp.get_clients({ name = "roslyn" })[1]

        if client then
            client:notify('workspace/didChangeWatchedFiles', {
                changes = {
                    {
                        uri = vim.api.nvim_buf_get_name(0),
                        type = 2
                    }
                }
            })
        end
    end,
})

vim.api.nvim_create_user_command('DotnetClass', function() require('files').insert_csharp_file_starter_into_current_buffer() end, {})
vim.api.nvim_create_user_command('DotnetInterface', function() require('files').insert_csharp_file_starter_into_current_buffer() end, {})
vim.api.nvim_create_user_command('DotnetTest', function() require('ui.picker').template_picker() end, {})

vim.g.loaded_dotnet_nvim  = true

