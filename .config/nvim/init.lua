-- 加载插件 
require('plugins')

-- 配置并启动插件
require('setup')

-- 设置使用更丰富的色彩
vim.opt.termguicolors = true

-- 默认显示行号
vim.opt.number = true

-- 设置行号的显示颜色
vim.cmd("highlight LineNr ctermfg=grey")
