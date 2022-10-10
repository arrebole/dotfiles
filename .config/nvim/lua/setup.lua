-- 启用注释功能
require('Comment').setup()

-- 文件图标
require('nvim-web-devicons').setup()

-- 启用文件浏览器
require("nvim-tree").setup()

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


-- 语言服务器配置
local lspconfig = require('lspconfig')

-- C语言服务器配置
lspconfig.clangd.setup({
  capabilities = capabilities,
})

-- python 语言服务器配置
lspconfig.pyright.setup({
  capabilities = capabilities,
})

-- javascript 语言服务器
lspconfig.tsserver.setup({
  capabilities = capabilities,
})

-- lua 语言服务器
lspconfig.sumneko_lua.setup({
  capabilities = capabilities,
})

-- ----------------------------------------
-- cmp 配置
local cmp = require('cmp')

-- Add additional capabilities supported by nvim-cmp
local capabilities = require('cmp_nvim_lsp').update_capabilities(
  vim.lsp.protocol.make_client_capabilities()
)

-- cmp 配置
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  }),
  sources = cmp.config.sources(
  {
    { name = 'nvim_lsp' },
  },
  {
    { name = 'buffer' },
  })
})