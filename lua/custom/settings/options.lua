-- Options on top of kickstart's SECTION 1. Loaded from init.lua right after it.

vim.o.wrap = false
vim.o.sidescrolloff = 8
vim.o.pumheight = 12
vim.o.laststatus = 3 -- one statusline for all splits
vim.o.virtualedit = 'block' -- visual-block can go past the end of a line

-- 2-space default; guess-indent adapts per file, and autocmds.lua sets C#/SQL/XML to 4.
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.softtabstop = 2

vim.o.swapfile = false

-- Treesitter folds (SECTION 9) start fully open.
vim.o.foldlevel = 99

-- Nothing here uses the Perl/Ruby/Python/Node remote-plugin hosts; skipping them keeps
-- :checkhealth clean and startup fast.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0
