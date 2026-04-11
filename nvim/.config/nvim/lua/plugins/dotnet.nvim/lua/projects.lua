local windows = require('ui.window')
local pickers = require('ui.picker')

local M = {}


--Create add new template
M.create_new_template = function ()
   pickers.dotnet_new_picker()
end

-- Add/Remove/Update References to existing project via multiselect 

-- Install Nuget to multiple Projects
-- Make it a bit more user friendly + let nuget sources be customised


M.create_new_template()

return M
