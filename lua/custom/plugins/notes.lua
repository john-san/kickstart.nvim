-- Plain-markdown notes in ~/notes, edited with obsidian.nvim (the Obsidian app is not needed).
-- Skipped entirely on a machine without that folder, so the config still loads anywhere.
local paths = require 'custom.paths'

vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }
require('render-markdown').setup { completions = { lsp = { enabled = true } } }

if not vim.uv.fs_stat(paths.vault) then return end

vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  { src = 'https://github.com/obsidian-nvim/obsidian.nvim', version = vim.version.range '*' },
}

require('obsidian').setup {
  legacy_commands = false,
  workspaces = { { name = 'work', path = paths.vault } },
  notes_subdir = 'items',
  new_notes_location = 'notes_subdir',
  daily_notes = { folder = 'daily', date_format = '%Y-%m-%d', template = 'daily.md' },
  templates = { folder = 'templates', date_format = '%Y-%m-%d', time_format = '%H:%M' },
  attachments = { folder = '_resources' },
  ui = { enable = false }, -- render-markdown owns rendering
}

local map = vim.keymap.set
map('n', '<leader>nf', function() require('telescope.builtin').find_files { cwd = paths.vault, prompt_title = 'Notes' } end, { desc = '[N]otes: [F]ind' })
map('n', '<leader>ng', function() require('telescope.builtin').live_grep { cwd = paths.vault, prompt_title = 'Grep notes' } end, { desc = '[N]otes: [G]rep' })
map('n', '<leader>nn', '<cmd>Obsidian new<CR>', { desc = '[N]otes: [N]ew' })
map('n', '<leader>ni', '<cmd>Obsidian new_from_template<CR>', { desc = '[N]otes: new from template' })
map('n', '<leader>nd', '<cmd>Obsidian today<CR>', { desc = "[N]otes: to[D]ay's daily" })
map('n', '<leader>ny', '<cmd>Obsidian yesterday<CR>', { desc = "[N]otes: [Y]esterday's daily" })
map('n', '<leader>nb', '<cmd>Obsidian backlinks<CR>', { desc = '[N]otes: [B]acklinks' })
map('n', '<leader>nt', '<cmd>Obsidian tags<CR>', { desc = '[N]otes: [T]ags' })
map('n', '<leader>nl', '<cmd>Obsidian follow_link<CR>', { desc = '[N]otes: follow [L]ink' })
map('n', '<leader>ns', '<cmd>Obsidian search<CR>', { desc = '[N]otes: [S]earch' })
