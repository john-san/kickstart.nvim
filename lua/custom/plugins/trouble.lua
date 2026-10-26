-- A real diagnostics/references panel. With a 30-project solution loaded, quickfix is not enough.
vim.pack.add { 'https://github.com/folke/trouble.nvim' }

require('trouble').setup {
  focus = true,
  warn_no_results = false,
  open_no_results = true,
  modes = {
    diagnostics = { filter = { severity = vim.diagnostic.severity.WARN } },
  },
}

local map = vim.keymap.set
map('n', '<leader>xx', '<cmd>Trouble diagnostics toggle<CR>', { desc = 'Diagnostics (Trouble)' })
map('n', '<leader>xX', '<cmd>Trouble diagnostics toggle filter.buf=0<CR>', { desc = 'Buffer diagnostics' })
map('n', '<leader>xs', '<cmd>Trouble symbols toggle<CR>', { desc = 'Symbol outline' })
map('n', '<leader>xl', '<cmd>Trouble lsp toggle<CR>', { desc = 'LSP refs/defs/impls' })
map('n', '<leader>xq', '<cmd>Trouble qflist toggle<CR>', { desc = 'Quickfix list' })
map('n', '<leader>xt', '<cmd>Trouble todo toggle<CR>', { desc = 'TODOs' })
