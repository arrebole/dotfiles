-- 在编辑窗口和文件树窗口中均可切换文件浏览器
vim.keymap.set("n", "<C-b>", "<Cmd>Neotree toggle<CR>", {
  silent = true,
  desc = "打开或关闭文件浏览器",
})