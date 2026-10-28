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

return M
