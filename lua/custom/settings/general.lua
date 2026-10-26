-- Under WSL, Neovim cannot reach the Windows clipboard on its own; win32yank bridges it.
-- Native Windows and Linux use their built-in clipboard providers instead.
if vim.fn.has 'wsl' == 1 then
  vim.g.clipboard = {
    name = 'win32yank-wsl',
    copy = {
      ['+'] = '/mnt/c/ProgramData/chocolatey/lib/win32yank/tools/win32yank.exe -i --crlf',
      ['*'] = '/mnt/c/ProgramData/chocolatey/lib/win32yank/tools/win32yank.exe -i --crlf',
    },
    paste = {
      ['+'] = '/mnt/c/ProgramData/chocolatey/lib/win32yank/tools/win32yank.exe -o --lf',
      ['*'] = '/mnt/c/ProgramData/chocolatey/lib/win32yank/tools/win32yank.exe -o --lf',
    },
    cache_enabled = 0,
  }
end

vim.api.nvim_create_autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('custom-term-open', { clear = true }),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'
    vim.cmd.startinsert()
  end,
})
