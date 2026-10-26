-- Training wheels: hardtime blocks hjkl/arrow spam and names the motion you should have used.
-- Delete this file once the habits stick.
vim.pack.add {
  'https://github.com/MunifTanjim/nui.nvim',
  'https://github.com/m4xshen/hardtime.nvim',
}

require('hardtime').setup {
  max_count = 3,
  disable_mouse = false,
  disabled_filetypes = { 'qf', 'trouble', 'neo-tree', 'mason', 'help', 'dbui', 'dbout', 'toggleterm' },
}

vim.keymap.set('n', '<leader>tH', '<cmd>Hardtime toggle<CR>', { desc = '[T]oggle [H]ardtime drills' })
