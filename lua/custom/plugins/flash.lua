-- Jump anywhere on screen: press s, type two characters, then the label that appears.
-- This is why mini.surround uses the gs prefix (init.lua SECTION 4).
vim.pack.add { 'https://github.com/folke/flash.nvim' }

local flash = require 'flash'
flash.setup {
  search = { mode = 'fuzzy' },
  jump = { history = true, register = true, nohlsearch = true },
  modes = {
    search = { enabled = true }, -- labels on ordinary / and ? searches too
    char = { enabled = true, jump_labels = true, multi_line = true }, -- f/t/F/T reach past the current line
  },
}

vim.keymap.set({ 'n', 'x', 'o' }, 's', flash.jump, { desc = 'Flash jump' })
vim.keymap.set({ 'n', 'x', 'o' }, 'S', flash.treesitter, { desc = 'Flash select syntax node' })
vim.keymap.set('o', 'r', flash.remote, { desc = 'Remote flash (e.g. yr<jump>iw)' })
vim.keymap.set({ 'o', 'x' }, 'R', flash.treesitter_search, { desc = 'Flash treesitter search' })
vim.keymap.set('c', '<C-s>', flash.toggle, { desc = 'Toggle flash in / search' })
