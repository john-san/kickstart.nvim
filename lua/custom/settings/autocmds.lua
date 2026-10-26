local function augroup(name) return vim.api.nvim_create_augroup('custom-' .. name, { clear = true }) end

-- Markdown is skipped: two trailing spaces there are a hard line break.
vim.api.nvim_create_autocmd('BufWritePre', {
  group = augroup 'trim-whitespace',
  callback = function(ev)
    if vim.bo[ev.buf].filetype == 'markdown' then return end
    local view = vim.fn.winsaveview()
    vim.cmd [[keeppatterns %s/\s\+$//e]]
    vim.fn.winrestview(view)
  end,
})

-- .NET and SQL Server convention is 4 spaces. guess-indent still wins for existing files
-- that use something else; this covers new files.
vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'indent-dotnet',
  pattern = { 'cs', 'sql', 'xml' },
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
  end,
})

vim.filetype.add {
  extension = {
    tsql = 'sql',
    csproj = 'xml',
    vbproj = 'xml',
    fsproj = 'xml',
    props = 'xml',
    targets = 'xml',
    nuspec = 'xml',
    resx = 'xml',
    config = 'xml', -- web.config / app.config
  },
  filename = {
    ['global.json'] = 'jsonc',
    ['omnisharp.json'] = 'jsonc',
    ['tsconfig.json'] = 'jsonc',
    ['nuget.config'] = 'xml',
    ['NuGet.Config'] = 'xml',
    ['packages.config'] = 'xml',
  },
}

vim.api.nvim_create_autocmd('BufReadPost', {
  group = augroup 'last-location',
  callback = function(ev)
    if vim.tbl_contains({ 'gitcommit', 'gitrebase' }, vim.bo[ev.buf].filetype) then return end
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then pcall(vim.api.nvim_win_set_cursor, 0, mark) end
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = augroup 'close-with-q',
  pattern = { 'help', 'qf', 'man', 'checkhealth' },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set('n', 'q', '<cmd>close<CR>', { buffer = ev.buf, silent = true })
  end,
})

-- Saving a new file into a folder that does not exist yet creates the folder.
vim.api.nvim_create_autocmd('BufWritePre', {
  group = augroup 'auto-mkdir',
  callback = function(ev)
    if ev.match:match '^%w%w+://' then return end
    local file = vim.uv.fs_realpath(ev.match) or ev.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':p:h'), 'p')
  end,
})
