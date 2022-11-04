local set_keymap = vim.keymap.set
local lsp_buf = vim.lsp.buf

local servers = {
  "gopls",
  "sumneko_lua",
  "rust_analyzer",
}

local on_attach = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local bufopts = { noremap=true, silent=true, buffer=bufnr }
  set_keymap('n', 'gD', lsp_buf.declaration, bufopts)
  set_keymap('n', 'gd', lsp_buf.definition, bufopts)
  set_keymap('n', 'K', lsp_buf.hover, bufopts)
  set_keymap('n', 'gi', lsp_buf.implementation, bufopts)
  set_keymap('n', '<C-k>', lsp_buf.signature_help, bufopts)
  set_keymap('n', '<space>wa', lsp_buf.add_workspace_folder, bufopts)
  set_keymap('n', '<space>wr', lsp_buf.remove_workspace_folder, bufopts)
  set_keymap('n', '<space>wl', function()
    print(vim.inspect(lsp_buf.list_workspace_folders()))
  end, bufopts)
  set_keymap('n', '<space>D', lsp_buf.type_definition, bufopts)
  set_keymap('n', '<space>rn', lsp_buf.rename, bufopts)
  set_keymap('n', '<space>ca', lsp_buf.code_action, bufopts)
  set_keymap('n', 'gr', lsp_buf.references, bufopts)
  set_keymap('n', '<space>f', lsp_buf.formatting, bufopts)
end

local nvim_lsp = require("lspconfig")
for _, server in ipairs(servers) do 
  nvim_lsp[server].setup({
    on_attach = on_attach,
  })
end
