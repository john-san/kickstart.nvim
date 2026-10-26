-- vim-dadbod: run SQL from a buffer and browse schemas in a drawer (<leader>D).
-- Connections come from the gitignored lua/custom/local.lua; see local.example.lua.
-- SQL Server connections shell out to sqlcmd, which must be on PATH.
vim.pack.add {
  'https://github.com/tpope/vim-dadbod',
  'https://github.com/kristijanhusak/vim-dadbod-ui',
  'https://github.com/kristijanhusak/vim-dadbod-completion',
}

-- dadbod percent-decodes the URL, so a password containing '@' or '/' must be encoded going in.
local function url_encode(s)
  return (s:gsub('[^%w%-%._~]', function(c) return string.format('%%%02X', c:byte()) end))
end

local function connections()
  if not vim.api.nvim_get_runtime_file('lua/custom/local.lua', false)[1] then return {} end
  local dbs = {}
  for _, db in ipairs(require('custom.local').dbs or {}) do
    local url = db.url
    if db.password_env then
      local pw = vim.env[db.password_env]
      -- Function replacement: the encoded password contains '%', which gsub treats as special.
      url = pw and pw ~= '' and url:gsub('{pw}', function() return url_encode(pw) end) or nil
    end
    if url then table.insert(dbs, { name = db.name, url = url }) end
  end
  return dbs
end

vim.g.dbs = connections()
vim.g.db_ui_use_nerd_fonts = 1
vim.g.db_ui_execute_on_save = 0 -- the default runs the whole buffer on every :w
vim.g.db_ui_save_location = require('custom.paths').vault_sql -- saved queries live with the notes
vim.g.db_ui_win_position = 'left'
vim.g.db_ui_winwidth = 35
vim.g.db_ui_show_database_icon = 1
vim.g.db_ui_auto_execute_table_helpers = 1
vim.g.db_ui_force_echo_notifications = 1

-- Running a query is buffer-local: see after/ftplugin/sql.lua.
local map = vim.keymap.set
map('n', '<leader>Du', '<cmd>DBUIToggle<CR>', { desc = 'Toggle DB drawer' })
map('n', '<leader>Df', '<cmd>DBUIFindBuffer<CR>', { desc = 'Find DB buffer' })
map('n', '<leader>Dn', '<cmd>DBUIRenameBuffer<CR>', { desc = 'Rename DB buffer' })
map('n', '<leader>Dl', '<cmd>DBUILastQueryInfo<CR>', { desc = 'Last query info' })
map('n', '<leader>Da', '<cmd>DBUIAddConnection<CR>', { desc = 'Add connection' })
