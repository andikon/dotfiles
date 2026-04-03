local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local entry_display = require "telescope.pickers.entry_display"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local utils = require "utils"

local M = {}

local function create_picker(opts)
    opts = opts or {}

    pickers.new(opts, {
        prompt_title = opts.prompt_title,
        finder = opts.finder,
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)

                opts.after_selection(selection)
            end)
            return true
        end,
    }):find()
end

M.dotnet_new_picker = function()
    local templates = utils.get_dotnet_templates()
    if not templates or #templates == 0 then
        print("No templates found!")
        return
    end

    -- Create a display with columns
    local displayer = entry_display.create {
        separator = " │ ",
        items = {
            { width = 40 }, -- Name
            { width = 15 }, -- Short Key
            { width = 10 }, -- Language
            { width = 10 }, -- Type
            { width = 10 }, -- Type
            { width = 10 }, -- Path / Author
        },
    }

    local entry_maker = function(entry)
        return {
            value = entry[2],
            display = function()
                return displayer {
                    entry[1], -- Name
                    entry[2], -- Short Key
                    entry[3], -- Language
                    entry[4], -- Type
                    entry[5], -- Type
                    entry[6], -- Path
                }
            end,
            ordinal = table.concat(entry, " "), -- search across all fields
            item = entry
        }
    end

    local opts = {
        prompt_title = "Select .NET Template",
        finder = finders.new_table {
            results = templates,
            entry_maker = entry_maker,
        },
        after_selection = function(selection)
            -- selction value can be a comma separated list so just take the first
            local value = selection.value:match("([^,]+)")

            local cmd = "dotnet new " .. value
            vim.ui.input({
                prompt = "Do you want to name the " .. selection.item[1] .. "? (Empty for Default):",
                default = "",
            }, function(input)
                if input then
                    input = input:match("^%s*(.-)%s*$")
                    cmd = cmd .. "  -n " .. input
                end
            end)

            print(vim.fn.system(cmd))
        end,
    }

    create_picker(opts)
end

M.dotnet_project_picker = function()
    local templates = utils.get_dotnet_projects()
    if not templates or #templates == 0 then
        print("No templates found!")
        return
    end

    -- Create a display with columns
    local displayer = entry_display.create {
        separator = " │ ",
        items = {
            { width = 40 }, -- Name
            { width = 15 }, -- Short Key
            { width = 10 }, -- Language
            { width = 10 }, -- Type
            { width = 10 }, -- Type
            { width = 10 }, -- Path / Author
        },
    }

    local entry_maker = function(entry)
        return {
            value = entry[2],
            display = function()
                return displayer {
                    entry[1], -- Name
                    entry[2], -- Short Key
                    entry[3], -- Language
                    entry[4], -- Type
                    entry[5], -- Type
                    entry[6], -- Path
                }
            end,
            ordinal = table.concat(entry, " "), -- search across all fields
            item = entry
        }
    end

    local opts = {
        prompt_title = "Select .NET Template",
        finder = finders.new_table {
            results = templates,
            entry_maker = entry_maker,
        },
        after_selection = function(selection)
            -- selction value can be a comma separated list so just take the first
            local value = selection.value:match("([^,]+)")

            local cmd = "dotnet new " .. value
            vim.ui.input({
                prompt = "Do you want to name the " .. selection.item[1] .. "? (Empty for Default):",
                default = "",
            }, function(input)
                if input then
                    input = input:match("^%s*(.-)%s*$")
                    cmd = cmd .. "  -n " .. input
                end
            end)

            print(vim.fn.system(cmd))
        end,
    }

    M.create_picker(opts)
end

return M
