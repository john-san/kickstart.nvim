-- Treesitter text-object queries (used by mini.ai's f/c objects in init.lua) plus
-- function/class jumps and parameter swapping.
-- No ]a/[a parameter jumps: since 0.11 those are Neovim's own argument-list maps.
vim.pack.add { { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'main' } }

require('nvim-treesitter-textobjects').setup { move = { set_jumps = true } }

local move = require 'nvim-treesitter-textobjects.move'
local swap = require 'nvim-treesitter-textobjects.swap'

local function jump(lhs, fn, query, desc)
  vim.keymap.set({ 'n', 'x', 'o' }, lhs, function() move[fn](query, 'textobjects') end, { desc = desc })
end
jump(']f', 'goto_next_start', '@function.outer', 'Next function start')
jump('[f', 'goto_previous_start', '@function.outer', 'Previous function start')
jump(']F', 'goto_next_end', '@function.outer', 'Next function end')
jump('[F', 'goto_previous_end', '@function.outer', 'Previous function end')
jump(']]', 'goto_next_start', '@class.outer', 'Next class start')
jump('[[', 'goto_previous_start', '@class.outer', 'Previous class start')

vim.keymap.set('n', '<leader>a', function() swap.swap_next '@parameter.inner' end, { desc = 'Swap parameter with next' })
vim.keymap.set('n', '<leader>A', function() swap.swap_previous '@parameter.inner' end, { desc = 'Swap parameter with previous' })
