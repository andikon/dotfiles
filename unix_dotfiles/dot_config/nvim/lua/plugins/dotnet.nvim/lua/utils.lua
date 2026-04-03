local M = {}

M.WarningMsg = function(text)
    vim.api.nvim_echo({ { text, "WarningMsg" } }, false, {})
end

M.to_unix_path = function(path)
    return string.gsub(path, "\\", "/")
end

M.is_charp_file = function(filename)
    return string.sub(filename, - #'.cs') == '.cs'
end

M.is_current_buf_empty = function()
    return #vim.api.nvim_buf_get_lines(0, 1, -1, false) == 0
end

---@class dotnet.ProjectInformation
---@field project_dir string
---@field project_file string

---@param file_path string
---@return dotnet.ProjectInformation|nil
M.get_project_dir = function(file_path)
    local parent_dir = function(path)
        return path:match("(.+)/[^/]+$")
    end

    --TODO for references i think i need to get all projects in sln file directory
    --so maybe search until SLN and then recursivly all folders there for eaech csproj file
    local current_dir = parent_dir(file_path)

    local project_dir = nil;
    while project_dir == nil and current_dir:match("/") do
        local dotnet_project_file_extensions_patterns = { ".csproj$", ".sln$", ".slnx$", ".slnf$" }
        local files = require('plenary.scandir').scan_dir(current_dir,
            { depth = 1, search_pattern = dotnet_project_file_extensions_patterns })
        local dotnet_project_file_found = #files ~= 0
        if dotnet_project_file_found then
            return {
                project_dir = current_dir,
                project_file = files[1]
            }
        end
        current_dir = parent_dir(current_dir)
    end

    M.WarningMsg("Current directory is not a .NET project")
    return nil
end

---@class dotnet.FileInformation
---@field namespace string
---@field type_name string
---parses the file_path to get the namespace and class_name
---@param file_path string an already cleaned up unix path
---@return dotnet.FileInformation|nil # table with the namespace and class_name information
M.get_namespace = function(file_path)
    file_path = M.to_unix_path(file_path)
    local project_dir = M.get_project_dir(file_path)

    if project_dir == nil then
        return
    end

    -- namespace
    local start_index = string.find(project_dir.project_dir, "/[^/]*$") + 1
    local end_index = string.find(file_path, "/[^/]*$") - 1

    local path_from_project_to_target = file_path:sub(start_index, end_index)
    local namespace = path_from_project_to_target:gsub("/", ".")

    -- class
    local type_name = string.match(file_path, ".*/([^/]+)%.cs$")

    return {
        namespace = namespace,
        type_name = type_name,
    }
end

M.get_dotnet_templates = function(opts)
    opts = opts or {}
    local cmd = "dotnet new list --columns-all"
    local cmd_result = vim.fn.system(cmd)

    local lines = {}
    for line in cmd_result:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local result = {}
    for index, value in ipairs(lines) do
        if index > 4 then
            value = value:gsub("  ", "~")

            local row = {}
            for part in value:gmatch("[^~]+") do
                local trimmed = part:match("^%s*(.-)%s*$")
                table.insert(row, trimmed)
            end

            table.insert(result, row)
        end
    end
    return result
end

M.get_dotnet_projects = function()
    local cmd = "dotnet new list --columns-all"
    local cmd_result = vim.fn.system(cmd)

    local lines = {}
    for line in cmd_result:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local result = {}
    for index, value in ipairs(lines) do
        if index > 4 then
            value = value:gsub("  ", "~")

            local row = {}
            for part in value:gmatch("[^~]+") do
                local trimmed = part:match("^%s*(.-)%s*$")
                table.insert(row, trimmed)
            end

            table.insert(result, row)
        end
    end
    return result
end


return M
