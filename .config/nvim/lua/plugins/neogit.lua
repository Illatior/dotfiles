return {
    "TimUntersberger/neogit",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        { "<leader>gs", "<cmd>Neogit<cr>", desc = "[G]it [S]tatus" },
    },
    opts = {
        integrations = {
            diffview = true,
        },
    },
}
