vim.pack.add({
  { src = "https://github.com/lewis6991/gitsigns.nvim", version = vim.version.range("2") },
})

require("gitsigns").setup(require("plugins.gitsigns.config"))
vim.opt.signcolumn = "yes"
