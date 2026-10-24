

-- 编辑器默认显示行号
vim.opt.number = true
-- 真彩色（文件浏览器的图标与高亮需要）
vim.opt.termguicolors = true
-- 浮动窗口轻度透明
vim.opt.winblend = 10  
-- 弹出菜单轻度透明
vim.opt.pumblend = 10
-- 无行号不显示 ~
vim.opt.fillchars = { eob = ' ' } 
-- 背景透明
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
vim.api.nvim_set_hl(0, "NonText", { bg = "none" })
