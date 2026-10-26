vim.pack.add { 'https://github.com/folke/zen-mode.nvim' }

require('zen-mode').setup {
  window = {
    width = 120, -- Keep text centered at 120 chars
    options = {
      number = true, -- Keep absolute numbers
      relativenumber = true, -- Keep relative numbers
    },
  },
}

-- Not enabled at startup: zen mode is a float over the real window, so :q would only close it.
vim.keymap.set('n', '<leader>z', function()
  require('zen-mode').toggle()
end, { desc = 'Toggle Zen Mode' })
