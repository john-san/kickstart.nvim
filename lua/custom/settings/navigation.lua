-- Center screen after jumping
local opts = { noremap = true, silent = true }

-- Move up/down and center screen
vim.keymap.set("n", "<C-d>", "<C-d>zz", opts)
vim.keymap.set("n", "<C-u>", "<C-u>zz", opts)
vim.keymap.set("n", "<C-f>", "<C-f>zz", opts)
vim.keymap.set("n", "<C-b>", "<C-b>zz", opts)

-- Go to top/bottom and center
vim.keymap.set("n", "G", "Gzz", opts)
vim.keymap.set("n", "gg", "ggzz", opts)

-- Search results center
vim.keymap.set("n", "n", "nzz", opts)
vim.keymap.set("n", "N", "Nzz", opts)
vim.keymap.set("n", "*", "*zz", opts)
vim.keymap.set("n", "#", "#zz", opts)
vim.keymap.set("n", "g*", "g*zz", opts)
vim.keymap.set("n", "g#", "g#zz", opts)

-- Jump lists (next/prev jumps)
vim.keymap.set("n", "<C-o>", "<C-o>zz", opts)
vim.keymap.set("n", "<C-i>", "<C-i>zz", opts)

-- Quickfix list centering
vim.keymap.set("n", "]q", "]qzz", opts)
vim.keymap.set("n", "[q", "[qzz", opts)


-- Center on search jumps
vim.api.nvim_create_autocmd("CmdlineEnter", {
    pattern = "[/\\?]",
    callback = function()
        vim.defer_fn(function()
            vim.cmd("nnoremap <silent> <expr> <CR> 'zz'")
        end, 10)
    end,
})
