vim.pack.add { 'https://github.com/akinsho/toggleterm.nvim' }

require('toggleterm').setup {
  size = 20,
  open_mapping = [[<C-\>]],
  hide_numbers = true,
  shade_terminals = true,
  shading_factor = 2,
  direction = 'float', -- Options: "horizontal" | "vertical" | "float" | "tab"
  close_on_exit = true,
  shell = vim.o.shell,
}
