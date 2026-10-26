-- File explorer. Loaded at startup, so `nvim .` opens the tree instead of an empty buffer.
vim.pack.add {
  { src = 'https://github.com/nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/MunifTanjim/nui.nvim',
}

require('neo-tree').setup {
  close_if_last_window = true,
  popup_border_style = 'rounded',
  filesystem = {
    follow_current_file = { enabled = true },
    use_libuv_file_watcher = true, -- pick up changes made outside nvim (git checkout, builds)
    filtered_items = {
      hide_dotfiles = false,
      hide_gitignored = true,
      hide_by_name = { 'node_modules', 'bin', 'obj', '.angular', '.vs' },
    },
    window = {
      mappings = {
        ['\\'] = 'close_window',
      },
    },
  },
  window = {
    width = 34,
    mappings = {
      ['<space>'] = 'none', -- leave <space> to the leader key
      ['l'] = 'open',
      ['h'] = 'close_node',
      ['s'] = 'open_vsplit',
      ['S'] = 'open_split',
      ['Y'] = 'copy_to_clipboard',
    },
  },
}

vim.keymap.set('n', '\\', '<cmd>Neotree reveal<CR>', { desc = 'NeoTree reveal', silent = true })
vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle<CR>', { desc = 'File [E]xplorer' })
