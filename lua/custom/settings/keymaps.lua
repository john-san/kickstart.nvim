-- Keymaps on top of kickstart's. Plugin-specific maps live with their plugin in
-- lua/custom/plugins/; `<leader>sk` searches every keymap, wherever it was defined.
--
-- Leader groups used on top of kickstart's (s, t, h, gr):
--   <leader>x  trouble   <leader>l  lsp / plugins   <leader>D  database
--   <leader>n  notes     <leader>c  claude code     gs         surround (flash owns `s`)
local map = vim.keymap.set

require('which-key').add {
  { '<leader>x', group = 'Trouble' },
  { '<leader>l', group = '[L]SP / plugins' },
  { '<leader>D', group = '[D]atabase' },
  { '<leader>n', group = '[N]otes' },
  { '<leader>c', group = '[C]laude Code', mode = { 'n', 'x' } },
  { 'gs', group = '[S]urround', mode = { 'n', 'x' } },
}

map('n', '<leader>w', '<cmd>write<CR>', { desc = '[W]rite file' })
map('n', '<leader>Q', '<cmd>qall<CR>', { desc = '[Q]uit all' })

map('x', '<', '<gv', { desc = 'Outdent, keep selection' })
map('x', '>', '>gv', { desc = 'Indent, keep selection' })

-- On Alt rather than J/K so visual J (join) and K (hover) keep working.
map('n', '<A-j>', '<cmd>move .+1<CR>==', { desc = 'Move line down' })
map('n', '<A-k>', '<cmd>move .-2<CR>==', { desc = 'Move line up' })
map('i', '<A-j>', '<Esc><cmd>move .+1<CR>==gi', { desc = 'Move line down' })
map('i', '<A-k>', '<Esc><cmd>move .-2<CR>==gi', { desc = 'Move line up' })
map('x', '<A-j>', ":move '>+1<CR>gv=gv", { desc = 'Move selection down' })
map('x', '<A-k>', ":move '<-2<CR>gv=gv", { desc = 'Move selection up' })

map({ 'n', 'x' }, '<leader>d', [["_d]], { desc = '[D]elete without yanking' })
map('n', 'J', 'mzJ`z', { desc = 'Join lines, keep cursor' })

map('n', '<C-Up>', '<cmd>resize +2<CR>', { desc = 'Grow window height' })
map('n', '<C-Down>', '<cmd>resize -2<CR>', { desc = 'Shrink window height' })
map('n', '<C-Left>', '<cmd>vertical resize -2<CR>', { desc = 'Shrink window width' })
map('n', '<C-Right>', '<cmd>vertical resize +2<CR>', { desc = 'Grow window width' })
map('n', '<leader>-', '<C-w>s', { desc = 'Split below' })
map('n', '<leader>|', '<C-w>v', { desc = 'Split right' })

-- 'scrollbind' only follows the focused window, so the wheel over an unfocused diff pane
-- scrolled it alone. Focus that pane first so both sides of a diff move together.
for _, wheel in ipairs { '<ScrollWheelUp>', '<ScrollWheelDown>' } do
  map('n', wheel, function()
    local win = vim.fn.getmousepos().winid
    if win ~= 0 and vim.wo[win].diff then vim.api.nvim_set_current_win(win) end
    vim.api.nvim_feedkeys(vim.keycode(wheel), 'n', false)
  end, { desc = 'Scroll; focus the diff pane under the mouse first' })
end

-- kickstart's <leader>sc is commands, so git pickers take the capitals.
map('n', '<leader>sG', function() require('telescope.builtin').git_status() end, { desc = '[S]earch [G]it status' })
map('n', '<leader>sC', function() require('telescope.builtin').git_commits() end, { desc = '[S]earch git [C]ommits' })

-- <leader>tw is gitsigns' word diff in kickstart, so wrap is on the capital.
map('n', '<leader>tW', function() vim.o.wrap = not vim.o.wrap end, { desc = '[T]oggle [W]rap' })
map('n', '<leader>ts', function() vim.o.spell = not vim.o.spell end, { desc = '[T]oggle [S]pell' })
map('n', '<leader>tr', function() vim.o.relativenumber = not vim.o.relativenumber end, { desc = '[T]oggle [R]elative numbers' })
map('n', '<leader>tf', function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  vim.notify('Format on save: ' .. (vim.g.disable_autoformat and 'OFF' or 'ON'))
end, { desc = '[T]oggle [F]ormat on save' })

map('n', '<leader>lr', '<cmd>lsp restart<CR>', { desc = '[L]SP [R]estart' })
map('n', '<leader>li', '<cmd>checkhealth vim.lsp<CR>', { desc = '[L]SP [I]nfo' })
map('n', '<leader>lm', '<cmd>Mason<CR>', { desc = '[L]SP [M]ason' })
map('n', '<leader>lu', function() vim.pack.update() end, { desc = '[L]ist plugin [U]pdates (:w to apply)' })
