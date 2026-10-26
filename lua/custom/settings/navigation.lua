-- Keep the cursor centred after big jumps, so the eye never has to hunt for it.
local opts = { silent = true }

vim.keymap.set('n', '<C-d>', '<C-d>zz', opts)
vim.keymap.set('n', '<C-u>', '<C-u>zz', opts)
vim.keymap.set('n', '<C-f>', '<C-f>zz', opts)
vim.keymap.set('n', '<C-b>', '<C-b>zz', opts)

vim.keymap.set('n', 'G', 'Gzz', opts)
vim.keymap.set('n', 'gg', 'ggzz', opts)

-- zv opens any fold the match is hidden inside.
vim.keymap.set('n', 'n', 'nzzzv', opts)
vim.keymap.set('n', 'N', 'Nzzzv', opts)
vim.keymap.set('n', '*', '*zz', opts)
vim.keymap.set('n', '#', '#zz', opts)
vim.keymap.set('n', 'g*', 'g*zz', opts)
vim.keymap.set('n', 'g#', 'g#zz', opts)

vim.keymap.set('n', '<C-o>', '<C-o>zz', opts)
vim.keymap.set('n', '<C-i>', '<C-i>zz', opts)

-- ]q / [q are themselves default *mappings* (0.11+), not built-in keys, so a
-- non-recursive `]qzz` would do nothing. Call the commands directly.
vim.keymap.set('n', ']q', '<cmd>cnext<CR>zz', opts)
vim.keymap.set('n', '[q', '<cmd>cprevious<CR>zz', opts)

-- Centre after a / or ? search is submitted (not when it is cancelled with <Esc>).
vim.api.nvim_create_autocmd('CmdlineLeave', {
  group = vim.api.nvim_create_augroup('custom-center-search', { clear = true }),
  pattern = { '/', '?' },
  callback = function()
    if not vim.v.event.abort then vim.schedule(function() vim.cmd 'normal! zz' end) end
  end,
})
