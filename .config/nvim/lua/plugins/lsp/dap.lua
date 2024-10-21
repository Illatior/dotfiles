return {
    "mfussenegger/nvim-dap",
    dependencies = {
        "rcarriga/nvim-dap-ui",
        "theHamsta/nvim-dap-virtual-text",
        "nvim-neotest/nvim-nio",
        "leoluz/nvim-dap-go",
        "LiadOz/nvim-dap-repl-highlights",
    },
    config = function()
        local dap = require('dap')
        local dapui = require('dapui')
        local dap_virtualtext = require('nvim-dap-virtual-text')
        local dapgo = require('dap-go')

        dap.adapters.go = {
            type = "server",
            port = "${port}",
            executable = {
                command = vim.fn.stdpath("data") .. '/mason/bin/dlv',
                args = { "dap", "-l", "127.0.0.1:${port}" }
            },
            render = {
                max_type_length = 0,
            },
        }

        dap.configurations.go = {
            {
                type = "go",
                name = "Debug pakcage",
                request = "launch",
                program = "${workspaceFolder}",
            },
        }

        dapui.setup {
            render = {
                variable = function(var, render, indent, options)
                    local scope = var.scope or ""
                    local name = var.name or ""
                    local value = var.value or ""
                    local type = var.type or ""

                    -- Customize display format
                    local text = string.format("penisssssses", scope, name, value, type)
                    render(text, indent, options)
                end,
            }
        }
        dap_virtualtext.setup()
        dapgo.setup()
        require('nvim-dap-repl-highlights').setup()

        -- dapui.eval = function(exp)
        --     local session = dap.session()
        --     local result = session:request("evaluate")
        --     if type(result) == 'function' then
        --         dapui.run_command('repl.run', result) -- Call function in REPL
        --     else
        --         print(result)                         -- Print simple types
        --     end
        -- end

        vim.fn.sign_define('DapBreakpoint', { text = 'B' })

        vim.keymap.set("n", "<localleader>b", dap.toggle_breakpoint, { desc = "Debugger toggle [b]reakpoint" })
        vim.keymap.set("n", "<localleader>dx", function()
            dap.clear_breakpoints()
            print("breakpoints cleared")
        end, { desc = "[D]ebugger clear breakpoints" })

        vim.keymap.set("n", "<F1>", dap.continue, { desc = "continue debugger" })
        vim.keymap.set("n", "<F2>", dap.step_over, { desc = "step over" })
        vim.keymap.set("n", "<F3>", dap.step_into, { desc = "step into" })
        vim.keymap.set("n", "<F4>", dap.step_out, { desc = "step out" })
        vim.keymap.set("n", "<F5>", dap.step_back, { desc = "step back" })
        vim.keymap.set("n", "<F11>", dap.restart, { desc = "restart debugger" })
        vim.keymap.set("n", "<F11>", dap.terminate, { desc = "terminate debugger" })

        -- eval under cursor
        vim.keymap.set("n", "<localleader>?", function()
            require("dapui").eval(nil, { context = "repl", width = 100, height = 20, enter = true })
        end)

        -- Close debugger and clear breakpoints
        vim.keymap.set("n", "<localleader>de", dap.terminate, { desc = "[D]ebugger [e]xit" })

        dap.listeners.before.attach.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.launch.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated.dapui_config = function()
            dapui.close()
        end
        dap.listeners.before.event_exited.dapui_config = function()
            dapui.close()
        end
    end,
}
