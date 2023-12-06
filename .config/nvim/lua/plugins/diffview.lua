return {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        { "<leader>gc", "<cmd>Gitsigns preview_hunk<cr>", desc = "[G]it toggle diff [C]hunks" },
    },
    cmd = {
        "DiffviewOpen",
        "DiffviewClose",
        "DiffviewToggleFiles",
        "DiffviewFocusFiles",
    },
}
