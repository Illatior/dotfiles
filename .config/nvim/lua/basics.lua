local o = vim.opt

o.fileencoding = "utf-8"
o.number = true
o.relativenumber = true

o.laststatus = 3
o.ignorecase = true
o.hlsearch = true
o.scrolloff = 3
o.sidescrolloff = 5
o.numberwidth = 4
o.signcolumn = 'yes'
o.mouse = 'a'
o.history = 500
o.swapfile = false
o.cmdheight = 1
o.updatetime = 300
o.showmode = false
o.termguicolors = true
o.cursorline = true

o.showtabline = 2
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2

-- run :PackerCompile whenever plugins.lua is updated
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]])
