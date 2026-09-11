vim.pack.add { 'https://github.com/David-Kunz/gen.nvim' }

require('gen').setup {
  model = 'deepseek-coder:1.3b',
  api_host = 'http://localhost:11434',
  display_mode = 'popup',
}
