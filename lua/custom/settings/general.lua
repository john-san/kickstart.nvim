-- Enable clip to system keyboard
vim.g.clipboard = {
  name = "win32yank-wsl",
  copy = {
    ["+"] = "/mnt/c/ProgramData/chocolatey/lib/win32yank/tools/win32yank.exe -i --crlf",
    ["*"] = "/mnt/c/ProgramData/chocolatey/lib/win32yank/tools/win32yank.exe -i --crlf",
  },
  paste = {
    ["+"] = "/mnt/c/ProgramData/chocolatey/lib/win32yank/tools/win32yank.exe -o --lf",
    ["*"] = "/mnt/c/ProgramData/chocolatey/lib/win32yank/tools/win32yank.exe -o --lf",
  },
  cache_enabled = 0,
}

-- Update Terminal view
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    vim.cmd("setlocal nonumber norelativenumber") 
    vim.cmd("setlocal signcolumn=no")  -- Remove gutter
    vim.cmd("startinsert")  -- Start in insert mode
  end
})

-- Allow Ctrl + W to work inside terminal mode
vim.api.nvim_set_keymap('t', '<C-w>', [[<C-\><C-n><C-w>]], { noremap = true, silent = true })

-- Allow `:` in terminal mode by mapping it to Normal mode
vim.api.nvim_set_keymap('t', ':', [[<C-\><C-n>:]], { noremap = true, silent = true })