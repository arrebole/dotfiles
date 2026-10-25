vim.pack.add({
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/folke/noice.nvim", version = vim.version.range("4") },
})

-- 消息和命令行由 Noice 统一接管，不与本地 cmdpal 同时启用。
vim.o.laststatus = 3
vim.o.showcmd = false
vim.o.wildmode = "full"

require("noice").setup(require("plugins.noice.config"))
