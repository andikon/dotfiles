local M = {}

-- Text art works in terminals and Neovide without image protocols or external processes.
local brand = {
    [[   \     |     /   ]],
    [[    \    |    /    ]],
    [[     \   |   /     ]],
    [[      \  |  /      ]],
    [[       \ | /       ]],
    [[        \|/        ]],
    [[        /|\        ]],
    [[       / | \       ]],
    [[       \ | /       ]],
    [[        \|/        ]],
    [[         |         ]],
}
local compact_brand = {
    [[    \  |  /    ]],
    [[     \ | /     ]],
    [[      \|/      ]],
    [[      /|\      ]],
    [[      \|/      ]],
    [[       |       ]],
}

function M.header()
    local items = {}
    for _, line in ipairs(vim.o.lines < 42 and compact_brand or brand) do
        items[#items + 1] = { text = { { line, hl = "BerserkBrand" } }, align = "center" }
    end
    items[#items + 1] = { text = { { "B E R S E R K", hl = "BerserkTitle" } }, align = "center", padding = 1 }
    items[#items + 1] = { text = { { "STRUGGLE / ENDURE / CREATE", hl = "BerserkSubtle" } }, align = "center", padding = 1 }
    return items
end

function M.projects()
    local projects = require("projects").list()
    if #projects == 0 then return {} end
    local counts = {}
    for _, project in ipairs(projects) do counts[project.name] = (counts[project.name] or 0) + 1 end
    local items = { { title = "Recent projects", padding = 1 } }
    for i, project in ipairs(projects) do
        if i > 3 then break end
        local name = project.name
        if counts[name] > 1 then name = name .. " / " .. vim.fs.basename(vim.fs.dirname(project.path)) end
        items[#items + 1] = { desc = name, key = tostring(i), action = function() require("projects").open(project.path) end }
    end
    items[#items].padding = 1
    return items
end

return M
