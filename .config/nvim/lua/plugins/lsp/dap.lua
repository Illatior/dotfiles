return {
    "mfussenegger/nvim-dap",
    dependencies = {
        "rcarriga/nvim-dap-ui",
    },
    config = function()
        local dap = require('dap')
        dap.configurations = {
            go = {
                {
                    type = "go",
                    name = "Debug",
                    request = "launch",
                    program = "${file}",
                },
                {
                    type = "go",
                    name = "Debug test (go.mod)",
                    request = "launch",
                    mode = "test",
                    program = "./${relativeFileDirname}",
                },
                {
                    type = "go",
                    name = "Attach (Pick Process)",
                    mode = "local",
                    request = "attach",
                    processId = require('dap.utils').pick_process,
                },
                {
                    type = "go",
                    name = "Attach (127.0.0.1:9080)",
                    mode = "remote",
                    request = "attach",
                    port = "9080"
                },
            },
        }
        dap.adapters.go = {
            type = "server",
            port = "${port}",
            executable = {
                command = vim.fn.stdpath("data") .. '/mason/bin/dlv',
                args = { "dap", "-l", "127.0.0.1:${port}" }
            }
        }

        local dapui = require('dapui')
        dapui.setup {
            icons = { expanded = "|", collapsed = ">" },
            mappings = {
                open = "o",
                remove = "d",
                edit = "e",
                repl = "r",
                toggle = "t",
            },
            expand_lines = vim.fn.has("nvim-0.7"),
            layouts = {
                {
                    elements = {
                        "stacks",
                        "scopes",
                    },
                    size = 0.3,
                    position = "right",
                },
                {
                    elements = {
                        "repl",
                    },
                    size = 0.3,
                    position = "bottom",
                },
            },
            floating = {
                max_height = nil,
                max_width = nil,
                border = "single",
                mappings = {
                    close = { "q", "<Esc>" },
                },
            },
            windows = { indent = 1 },
            render = {
                max_type_length = nil,
            },
        }

        vim.fn.sign_define('DapBreakpoint', { text = 'B' })

        vim.keymap.set("n", "<leader>dtw", function()
            require("dapui").float_element("watches", {
                width = 640,
                height = 480,
                enter = true,
                position = "center",
            })
        end, { desc = "[D]ebugger [t]oggle [w]atches" })
        vim.keymap.set("n", "<leader>dtb", function()
            require("dapui").float_element("breakpoints", {
                width = 640,
                height = 480,
                enter = true,
                position = "center",
            })
        end, { desc = "[D]ebugger [t]oggle [b]reakpoints" })

        vim.keymap.set("v", "<M-k>", function()
            require('dapui').eval()
        end, { desc = "send highlighted text to repl" })

        -- Set breakpoints, get variable values, step into/out of functions, etc.
        vim.keymap.set("n", "<localleader>dl", require("dap.ui.widgets").hover)
        vim.keymap.set("n", "<localleader>dc", dap.continue, { desc = "[D]ebugger [c]ontinue" })
        vim.keymap.set("n", "<localleader>db", dap.toggle_breakpoint, { desc = "[D]ebugger toggle [b]reakpoint" })
        vim.keymap.set("n", "<localleader>dn", dap.step_over, { desc = "[D]ebugger step over" })
        vim.keymap.set("n", "<localleader>di", dap.step_into, { desc = "[D]ebugger step [i]nto" })
        vim.keymap.set("n", "<localleader>do", dap.step_out, { desc = "[D]ebugger step [o]ut" })
        vim.keymap.set("n", "<localleader>dx", function()
            dap.clear_breakpoints()
            print("breakpoints cleared")
        end, { desc = "[D]ebugger clear breakpoints" })

        -- Close debugger and clear breakpoints
        vim.keymap.set("n", "<localleader>de", dap.terminate, { desc = "[D]ebugger [e]xit" })

        dap.listeners.after.event_initialized["dapui_config"] = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated["dapui_config"] = function()
            dapui.close()
        end
        dap.listeners.before.event_exited["dapui_config"] = function()
            dapui.close()
        end
    end,
}
