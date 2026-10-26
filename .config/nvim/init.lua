-- Neovim 配置本体维护在 https://github.com/arrebole/wu.nvim
-- 这里只负责安装并启动该插件，保持 dotfiles 与配置实现解耦。
vim.pack.add({
  {
    src = "https://github.com/arrebole/wu.nvim",
  },
})

require("wu").setup({})
