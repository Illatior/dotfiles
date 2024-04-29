return {
    'stevearc/conform.nvim',
    opts = {},
    config = function ()
        require('conform').setup {
            format_on_save = {
                timeout_ms = 500,
                lsp_fallback = true,
                async = true,
            },
            formatter_by_ft = {
                lua = { "stylua" },
                go = { "gofmt" },
            },
        }
    end
}
