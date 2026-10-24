-- 只切换文件树显示状态，打开时不抢走编辑区焦点。
vim.keymap.set("n", "<C-b>", function()
  require("plugins.neo-tree.actions").toggle()
end, {
  silent = true,
  desc = "打开或关闭文件浏览器",
})

vim.keymap.set("n", "<C-S-b>", function()
  require("plugins.neo-tree.actions").switch_focus()
end, {
  silent = true,
  desc = "切换编辑区和文件浏览器焦点",
})

-- 按顶部标签栏的顺序切换 buffer。
vim.keymap.set("n", "[b", function()
  require("plugins.bufferline.navigation").cycle(-1)
end, {
  silent = true,
  desc = "切换到上一个 buffer",
})
vim.keymap.set("n", "]b", function()
  require("plugins.bufferline.navigation").cycle(1)
end, {
  silent = true,
  desc = "切换到下一个 buffer",
})
