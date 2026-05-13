-- return {
--   "rebelot/kanagawa.nvim",
--   config = function()
--     vim.cmd("colorscheme kanagawa")
--   end
-- }

return {
  "navarasu/onedark.nvim",
  priority = 1000, -- make sure to load this before all the other start plugins
  config = function()
    require('onedark').setup {
      transparent = true,
      style = 'deep',
      term_colors = true,
      ending_tildes = false,
      cmp_itemkind_reverse = false,

      code_style = {
        comments = 'italic',
        keywords = 'none',
        functions = 'none',
        strings = 'none',
        variables = 'none'
      },

      colors = {},
      highlights = {},

      diagnostics = {
        darker = true,
        undercurl = true,
        background = true,
      },
    }
  end,
}

-- return {
--     {
--         'navarasu/onedark.nvim',
--         opts = {
--             transparent = true,
--             style = 'deep',
--             term_colors = true,
--             ending_tildes = false,
--             cmp_itemkind_reverse = false,
--
--             code_style = {
--                 comments = 'italic',
--                 keywords = 'none',
--                 functions = 'none',
--                 strings = 'none',
--                 variables = 'none'
--             },
--
--             colors = {},
--             highlights = {},
--
--             diagnostics = {
--                 darker = true,
--                 undercurl = true,
--                 background = true,
--             },
--         },
--     },
-- }
