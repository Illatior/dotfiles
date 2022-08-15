require("nvim-treesitter.configs").setup({
  auto_install = true,
  ensure_insatlled = {
    "bash",
    "c",
    "cmake",
    "cpp",
    "c_sharp",
    "erlang",
    "fish",
    "go",
    "gomod",
    "gowork",
    "java",
    "javascript",
    "json",
    "lua",
    "make",
    "proto",
    "python",
    "ruby",
    "rust",
    "solidity",
    "sql",
    "yaml"
  },
  highlight = {
    enable = true,
  }
})
