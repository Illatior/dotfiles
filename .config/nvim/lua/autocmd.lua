local api = vim.api

api.nvim_create_autocmd(
  "BufEnter",
  { command = [[if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif]]}
)
