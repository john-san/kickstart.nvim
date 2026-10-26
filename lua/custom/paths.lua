-- The notes vault and dadbod's saved-query folder share one location, defined once here.
local M = {}

M.vault = vim.fs.normalize(vim.fs.joinpath(vim.uv.os_homedir(), 'notes'))
M.vault_sql = vim.fs.joinpath(M.vault, 'sql')

return M
