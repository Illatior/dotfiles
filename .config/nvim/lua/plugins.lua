local fn = vim.fn
local api = vim.api

local install_path = fn.stdpath("data") .. "/site/pack/packer/opt/packer.nvim"

-- bootstrap packer if not installed
if fn.empty(fn.glob(install_path)) > 0 then
  print("Installing packer...")
  fn.system({
    "git",
    "clone",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  })
 api.nvim_command("packadd packer.nvim")
end

-- configure packer
local packer = require("packer")

packer.init({
  enable = true,
  threshold = 0,
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end
  },
})

packer.startup(function(use)
  local function get_config(name)
    return string.format('require("config/%s")', name)
  end

  -- Packer
	use({"wbthomason/packer.nvim"})

  -- Theme
	use({ "navarasu/onedark.nvim", config = get_config("onedark") })

  -- Navigation
  use({ "kyazdani42/nvim-tree.lua", config = get_config("nvim-tree") })

  use({
    "nvim-telescope/telescope.nvim", branch = "0.1.x",
    requires = { {"nvim-lua/plenary.nvim" } },
    config = get_config("telescope")
  })
  use({'nvim-telescope/telescope-fzf-native.nvim', run = "make" })

  -- Status line
  use({
    "nvim-lualine/lualine.nvim",
    config = get_config("lualine"),
    requires = { 'kyazdani42/nvim-web-devicons', opt = true }
  })

  -- GIT-related plugins 
  use({
    "lewis6991/gitsigns.nvim",
    requires = { "nvim-lua/plenary.nvim" },
    config = get_config("gitsigns"),
  })

  use({
    "TimUntersberger/neogit",
    requires = { "nvim-lua/plenary.nvim" },
    config = get_config("neogit"),
  })

  use({
    "sindrets/diffview.nvim",
    requires = { "nvim-lua/plenary.nvim" },
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
    },
    config = get_config("diffview"),
  })

  -- Autopairs
  use({ "windwp/nvim-autopairs", config = get_config("autopairs") })

  -- Treesitter
  use({
    "nvim-treesitter/nvim-treesitter",
    config = get_config("treesitter"),
    run = ":TSUpdate",
  })

  -- LSP
  use({ "neovim/nvim-lspconfig", config = get_config("lspconfig") })
  use({ "williamboman/mason.nvim", config = get_config("mason") }) -- installer

  -- Completions
  use({
    "hrsh7th/nvim-cmp",
    requires = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
    },
    config = get_config("cmp")
  })

  use({
    "L3MON4D3/LuaSnip",
    requires = "saadparwaiz1/cmp_luasnip",
    --config = get_config("luasnip"),
  })

  -- TODO add which-key, git-blame, telescope, vgit.nvim
end)


