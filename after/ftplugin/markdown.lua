-- after/ftplugin/markdown.lua
-- Prose wants the opposite of what options.lua sets for code: soft wrapping at
-- word boundaries rather than no wrapping at all.

vim.opt_local.wrap = true
vim.opt_local.linebreak = true -- wrap at words, not mid-word
vim.opt_local.breakindent = true
vim.opt_local.spell = true
vim.opt_local.shiftwidth = 2
vim.opt_local.tabstop = 2
vim.opt_local.softtabstop = 2

-- render-markdown and obsidian.nvim both conceal link/emphasis syntax.
vim.opt_local.conceallevel = 2

-- With wrap on, j/k should move by screen line -- but only when there is no
-- count, so 5j still means five real lines. Mirrors the global maps in
-- keymaps.lua, which are overridden by these buffer-local ones.
vim.keymap.set({ "n", "x" }, "j", function()
  return vim.v.count == 0 and "gj" or "j"
end, { buffer = true, expr = true, desc = "Down (screen line)" })
vim.keymap.set({ "n", "x" }, "k", function()
  return vim.v.count == 0 and "gk" or "k"
end, { buffer = true, expr = true, desc = "Up (screen line)" })
