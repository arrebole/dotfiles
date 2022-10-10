" 加载插件 
lua require('plugins')

" 配置并启动插件
lua require('setup')

"" --------------------------------------------------------------------------------

"" 隐藏 Netrw 顶端的横幅（Banner
let g:netrw_banner = 0

"" Netrw打开文件的方式
"" 1.用水平拆分窗口打开文件
"" 2.用垂直拆分窗口打开文件
"" 3.用新建标签页打开文件
"" 4.用前一个窗口打开文件
"" let g:netrw_browse_split = 2


"" 在 netrw 中按 i 键，可以在 thin / long / wide / tree 模式切换
"" 选择默认模式是 tree 模式
"" let g:netrw_liststyle = 3

"" 设置 netrw 文件浏览器的宽度，主窗口的长度为90%
" let g:netrw_winsize = 95


"" ---------------------------------------------------------------------------------

"" 设置使用更丰富的色彩
set termguicolors

"" 默认显示行号
set number

"" 设置行号的显示颜色
highlight LineNr ctermfg=grey