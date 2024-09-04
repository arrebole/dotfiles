-- 启用注释功能
require('Comment').setup()

-- 文件图标
require('nvim-web-devicons').setup()

-- 启用文件浏览器
require("nvim-tree").setup({
  -- 禁用 netrw，这通常与 Nvim-Tree 冲突
  disable_netrw = true,
  hijack_netrw = true,
  open_on_tab = false,
  hijack_cursor = false,
  update_cwd = true,
  update_focused_file = {
    enable = true,
    update_cwd = true,
    ignore_list = {}
  },
})

-- 状态栏
require("lualine").setup()

-- 终端
require("toggleterm").setup()

-- 启用主题
require('github-theme').setup()

-- git 插件
require('gitsigns').setup()

-- 多文件打开
require('bufferline').setup({
  options = {
    -- 左侧让出 nvim-tree 的位置
    offsets = {{
      filetype = "NvimTree",
      text = "Files",
      highlight = "Directory",
      text_align = "left"
    }}
  }
})

-- ----------------------------------------

-- 语言服务器管理器
require('mason').setup()

-- cmp 配置
local cmp = require('cmp')
cmp.setup({
  mapping = {
    ['<Tab>'] = cmp.mapping.select_next_item(),
    ['<S-Tab>'] = cmp.mapping.select_prev_item(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }), -- 回车确认补全
  },
  sources = {
    { name = 'nvim_lsp' }, -- LSP 补全
    { name = 'buffer' }, -- 当前缓冲区补全
    { name = 'luasnip' }, -- 代码片段补全
  }
})

-- Set up lspconfig.
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- javascript 语言服务器
require('lspconfig').tsserver.setup({
  capabilities = capabilities,
})