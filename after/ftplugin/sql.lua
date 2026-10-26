-- after/ftplugin/sql.lua
-- Buffer-local dadbod bindings. Kept out of lua/config/keymaps.lua because
-- <Plug>(DBUI_*) only exists in a buffer dadbod has bound to a connection.

local function map(mode, lhs, plug, desc)
  vim.keymap.set(mode, lhs, plug, { buffer = true, desc = desc })
end

map("n", "<leader>Dr", "<Plug>(DBUI_ExecuteQuery)", "Run query")
map("x", "<leader>Dr", "<Plug>(DBUI_ExecuteQuery)", "Run selection")
map("n", "<leader>Dw", "<Plug>(DBUI_SaveQuery)", "Save query to vault")
map("n", "<leader>De", "<Plug>(DBUI_EditBindParameters)", "Edit bind parameters")
