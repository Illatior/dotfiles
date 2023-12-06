vim.keymap.set('n', '<leader>nh', '<cmd>:nohl<cr>', { desc = "[N]o [H]ighlight" })

-- remap for dealing with word wraps???
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- vim.keymap.set('n', '<leader>vsf', "<cmd>source %<cr>", { desc = "[V]im [S]ource current [F]ile" }) TODO
