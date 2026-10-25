
-- 在加载插件和快捷键之前设置 leader。
vim.g.mapleader = " "

-- tab键默认4格子
-- Tab 字符显示为 4 格
vim.opt.tabstop = 4      
-- 自动缩进、>> 和 << 使用 4 格
vim.opt.shiftwidth = 4   
-- 编辑时按 Tab、退格按 4 格处理
vim.opt.softtabstop = 4  

-- 不自动生成 XXX~ 的备份文件
vim.opt.backup = false
-- 所有模式都支持鼠标
vim.opt.mouse = "a"


-- 不自动换行
vim.opt.wrap = false
-- 编辑器默认显示行号
vim.opt.number = true
-- 当前指针编辑行高亮
vim.opt.cursorline = true
-- 真彩色（文件浏览器的图标与高亮需要）
vim.opt.termguicolors = true
-- 浮动窗口轻度透明
vim.opt.winblend = 10  
-- 弹出菜单轻度透明
vim.opt.pumblend = 10
-- 无行号不显示 ~
vim.opt.fillchars = { eob = " " }

-- 背景透明
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
vim.api.nvim_set_hl(0, "NonText", { bg = "none" })
