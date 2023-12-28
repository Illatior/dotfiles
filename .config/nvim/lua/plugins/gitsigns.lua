return {
    "lewis6991/gitsigns.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    lazy = false,
    keys = {
        { "<leader>gbt", "<cmd>Gitsigns toggle_current_line_blame<cr>", desc = "[G]it [B]lame [T]oggle" },
    },
    opts = {
        signs = {
            add = {
                text = "│",
            },
            change = {
                text = "│",
            },
            delete = {
                text = "_",
            },
            topdelete = {
                text = "‾",
            },
            changedelete = {
                text = "~",
            },
            untracked = {
                text = "┆",
            },
        },
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = false,
        watch_gitdir = {interval = 1000, follow_files = true},
        attach_to_untracked = true,

        current_line_blame = false,
        current_line_blame_opts = {
            virt_text = true,
            virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
            delay = 1000,
            ignore_whitespace = false,
            virt_text_priority = 100,
        },
        current_line_blame_formatter_opts = {
            relative_time = false
        },
        sign_priority = 6,
        update_debounce = 100,
        status_formatter = nil,
        max_file_length = 40000,
        preview_config = {
            border = "single",
            style = "minimal",
            relative = "cursor",
            row = 0,
            col = 1
        },
        diff_opts = {internal = true},
        yadm = {enable = false}
    }
}
