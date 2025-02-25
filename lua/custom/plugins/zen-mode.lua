return {
  {
        "folke/zen-mode.nvim",
        config = function()
            require("zen-mode").setup {
                window = {
                    width = 120, -- Keep text centered at 120 chars
                    options = {
                        number = true,  -- Keep absolute numbers
                        relativenumber = true, -- Keep relative numbers
                    }
                },
            }

            -- Auto-enable Zen Mode on startup
            vim.api.nvim_create_autocmd("VimEnter", {
                callback = function()
                    require("zen-mode").toggle()
                end
            })

            -- Add keybinding to toggle Zen Mode
            vim.keymap.set("n", "<leader>z", function()
                require("zen-mode").toggle()
            end, { desc = "Toggle Zen Mode" })
        end
    }
}