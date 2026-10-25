-- 浮动文件浏览器与文件查询。
vim.keymap.set("n", "<leader>dd", "<Cmd>Dashboard<CR>", { desc = "打开启动面板" })
vim.keymap.set("n", "<leader>ee", "<Cmd>Yazi<CR>", { desc = "Yazi：定位当前文件" })
vim.keymap.set("n", "<leader>eE", "<Cmd>YaziCwd<CR>", { desc = "Yazi：浏览工作目录" })
vim.keymap.set("n", "<leader>ff", "<Cmd>FzfFiles<CR>", { desc = "fzf：查询项目文件" })
vim.keymap.set("n", "<leader>fF", "<Cmd>FzfFilesCwd<CR>", { desc = "fzf：查询工作目录文件" })

-- 浮动 Shell 终端；数字前缀选择对应编号的终端。
vim.keymap.set("n", "<leader>tt", function()
  vim.cmd(tostring(vim.v.count) .. "ToggleTerm")
end, { desc = "切换悬浮终端" })
vim.keymap.set("n", "<leader>ts", "<Cmd>TermSelect<CR>", { desc = "选择终端" })

-- 消息与错误，leader 为空格。
vim.keymap.set("n", "<leader>nh", "<Cmd>Noice history<CR>", { desc = "查看消息历史" })
vim.keymap.set("n", "<leader>ne", "<Cmd>Noice errors<CR>", { desc = "查看错误消息" })
vim.keymap.set("n", "<leader>nl", "<Cmd>Noice last<CR>", { desc = "查看最近一条消息" })
vim.keymap.set("n", "<leader>nd", "<Cmd>Noice dismiss<CR>", { desc = "清除悬浮通知" })

-- Git 操作入口，leader 为空格。
vim.keymap.set("n", "<leader>gg", "<Cmd>LazyGit<CR>", { desc = "打开 LazyGit" })
vim.keymap.set("n", "<leader>gG", "<Cmd>LazyGitCurrentFile<CR>", { desc = "打开当前文件的 Git 仓库" })
vim.keymap.set("n", "<leader>gl", "<Cmd>LazyGitLog<CR>", { desc = "查看仓库提交历史" })
vim.keymap.set("n", "<leader>gf", "<Cmd>LazyGitFilterCurrentFile<CR>", { desc = "查看当前文件历史" })
vim.keymap.set("n", "<C-g>", function() require("plugins.lazygit").toggle() end, { desc = "切换 LazyGit" })

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
