return {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
        { 'hrsh7th/cmp-nvim-lsp' },
        { "antosha417/nvim-lsp-file-operations", config = true },
        { 'j-hui/fidget.nvim',                   tag = 'legacy' },
    },
    config = function()
        local servers = {
            gopls = {
                settings = {
                    gopls = {
                        gofumpt = true,
                        usePlaceholders = true,
                        staticcheck = true,
                        completeFunctionCalls = true, -- new
                        analyses = {
                            unusedparams = true,
                            unusedvariable = true,
                            unusedwrite = true,
                            unusedresult = true,
                            shadow = true,
                        },
                        hints = {
                            assignVariableTypes = true,
                            compositeLiteralFields = true,
                            compositeLiteralTypes = true,
                            constantValues = true,
                            functionTypeParameters = true,
                            parameterNames = true,
                            rangeVariableTypes = true,
                        },
                    },
                },
            },
            lua_ls = {
                settings = {
                    Lua = {
                        -- make the language server recognize "vim" global
                        diagnostics = {
                            globals = { "vim" },
                        },
                        workspace = {
                            -- make language server aware of runtime files
                            library = {
                                [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                                [vim.fn.stdpath("config") .. "/lua"] = true,
                            },
                        },
                    }
                }
            },
            solidity_ls_nomicfoundation = {},
            tsserver = {},
            docker_compose_language_service = {},
            dockerls = {},
            java_language_server = {},
            -- godot = {},
        }

        local on_attach = function(_, bufnr)
            local nmap = function(keys, func, desc)
                if desc then
                    desc = "LSP: " .. desc
                end

                vim.keymap.set('n', keys, func, { noremap = true, buffer = bufnr, silent = true, desc = desc })
            end

            nmap('K', vim.lsp.buf.hover, "[K] hover documentation")
            nmap('gd', vim.lsp.buf.definition, "[G]oto [D]efinition")

            nmap("gd", "<cmd>Telescope lsp_definitions<CR>", "[g]oto [d]efinition")
            nmap("gD", vim.lsp.buf.declaration, "[g]oto [D]eclaration")
            nmap("gi", "<cmd>Telescope lsp_implementations<CR>", "[g]oto [i]mplementation")
            nmap("go", "<cmd>Telescope lsp_type_definitions", "[g]oto type definition")
            nmap("<C-s>", vim.lsp.buf.signature_help, "signature help")
            nmap("gf", "<cmd>Telescope lsp_references<CR>", "[g]oto references")
            nmap("K", vim.lsp.buf.hover, "hover documentation")
            nmap("<leader>vws", vim.lsp.buf.workspace_symbol, "workspace symbol")
            nmap("<leader>vd", vim.diagnostic.open_float, "open float")
            nmap("<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", "Show lsp buffer [D]iagnistics")
            nmap("<leader>d", vim.diagnostic.open_float, "Show [d]iagnistics for current line")
            nmap("]d", vim.diagnostic.goto_next, "goto next")
            nmap("[d", vim.diagnostic.goto_prev, "goto prev")
            nmap("<leader>rn", vim.lsp.buf.rename, "[r]e[n]ame")
            nmap(
                '<leader>wl',
                function()
                    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                end,
                '[W]orkspace [L]ist Folders'
            )
            vim.keymap.set(
                { 'n', 'v' },
                "<leader>ca",
                vim.lsp.buf.code_action,
                { noremap = true, buffer = bufnr, silent = true, desc = "lsp [c]ode [a]ctions" }
            )
        end
        vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", { noremap = true, silent = true, desc = "restart lsp" })


        local lsp = require('lspconfig')
        vim.tbl_extend('keep', lsp, {
            godot = {
                cmd = {},
                filetypes = ''
            }
        })

        local capabilities = require('cmp_nvim_lsp').default_capabilities()
        for server, server_opts in pairs(servers) do
            local opts = {
                capabilities = capabilities,
                on_attach = on_attach,
            }
            if server_opts.file_types ~= nil then
                opts.file_type = server_opts.file_types
            end
            if server_opts.settings ~= nil then
                opts.settings = server_opts.settings
            end

            lsp[server].setup(opts)
        end

        -- docker-compose lsp client fix
        local function set_filetype(pattern, filetype)
            vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
                pattern = pattern,
                command = "set filetype=" .. filetype,
            })
        end

        set_filetype({ "docker-compose.yml" }, "yaml.docker-compose")
        set_filetype({ "docker-compose.yaml" }, "yaml.docker-compose")

        require('fidget').setup {
            window = {
                blend = 0,
            },
        }
    end
}
