vim.pack.add({
  {
    src = "https://github.com/akinsho/bufferline.nvim",
    version = vim.version.range("4"),
  },
  "https://github.com/nvim-tree/nvim-web-devicons",
})

require("bufferline").setup(require("plugins.bufferline.config"))
