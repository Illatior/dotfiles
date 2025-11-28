local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local conf = require('telescope.config').values

local M = {}

local diagnostics = function(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  print(vim.inspect(require('telescope.builtin').diagnostics()))
end

M.setup = function()
  -- vim.keymap.set("n", "<leader>fg", diagnostics, { desc = "[F] Search with live [G]rep" })
end

-- diagnostics()

return M
