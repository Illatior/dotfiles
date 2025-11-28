return {
  "nvim-telescope/telescope.nvim",
  branch = '0.1.x',
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-telescope/telescope-dap.nvim",
  },
  opts = {
    defaults = {
      mappings = {
        i = {
        },
      },
    },
  },
  config = function()
    local telescope = require('telescope')
    local actions = require('telescope.actions')

    telescope.setup {
      defaults = {
        path_display = { "truncate " },
        mappings = {
          i = {
            ['<C-u>'] = false,
            ['<C-d>'] = false,

            -- ['<C-n>'] = false,
            -- ['<C-j>'] = actions.move_selection_next,

            -- ['<C-p>'] = false,
            -- ['<C-k>'] = actions.move_selection_previous,

            ['<C-w>'] = actions.send_selected_to_qflist + actions.open_qflist,
          },
        },
        file_ignore_patterns = {
          "node_modules",
          "build"
        },
      },
    }

    telescope.load_extension('fzf')
    -- telescope.load_extension('dap')

    vim.keymap.set('n', '<leader>K', function() require('telescope.builtin').keymaps() end,
      { desc = "[K]eymaps" })

    vim.keymap.set('n', '<leader>ff', function() require('telescope.builtin').find_files() end,
      { desc = "[F] Search [F]iles" })
    vim.keymap.set('n', '<leader>fs', function() require('telescope.builtin').git_files() end,
      { desc = "[F] Search Git files" })
    vim.keymap.set('n', '<leader>fh', function() require('telescope.builtin').help_tags() end,
      { desc = "[F] Search [H]elp" })
    vim.keymap.set('n', '<leader>fg', function() require('telescope.builtin').live_grep() end,
      { desc = "[F] Search with live [G]rep" })
    vim.keymap.set('n', '<leader>fd', function() require('telescope.builtin').diagnostics() end,
      { desc = "[F] Search [D]iagnostics" })
    vim.keymap.set('n', '<leader>fr', function() require('telescope.builtin').resume() end,
      { desc = "[F] Search [R]esume" })
    -- vim.keymap.set('n', '<leader>?', function() require('telescope.builtin').oldfiles() end,
    --     { desc = "[?] Search recetly opened files" })
    vim.keymap.set('n', '<leader><space>', function() require('telescope.builtin').buffers() end,
      { desc = "[ ] Search existing buffers" })
    vim.keymap.set(
      'n',
      '<leader>/',
      function()
        -- TODO pass additional configuration to telescope to change theme, layout, etc.
        require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end,
      { desc = "[/] Fuzzily search in current buffer" }
    )
  end,
}
