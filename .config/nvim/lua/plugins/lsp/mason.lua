return {
    "williamboman/mason.nvim",
    dependencies = {
        "williamboman/mason-lspconfig.nvim",
        -- "WhoIsSethDaniel/mason-tool-installer.nvim",
        "jay-babu/mason-nvim-dap.nvim",
    },
    config = function()
        require('mason').setup {
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗",
                },
            },
        }

        require('mason-lspconfig').setup {
            ensure_installed = {
               'gopls',
               'solidity_ls_nomicfoundation',
                'lua_ls',
               'pylsp',
            },
            automatic_installation = true,
        }

        require('mason-nvim-dap').setup {
            ensure_installed = {
                'delve',
            },
            handlers = {
                function(config)
                    require('mason-nvim-dap').default_setup(config)
                end,
            }
        }
    end,
}
