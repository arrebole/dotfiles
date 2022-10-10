-- nvim 插件管理
-- 使用 packer 安装/更新 插件

require('packer').startup(function()

  -- Packer 所有插件的包管理器
  -- 并使用 packer 管理自身
  use({
    'wbthomason/packer.nvim'
  })

  -- mason.vim 语言服务器的管理器，用于安装语言服务器
  use({
    'williamboman/mason.nvim'
  })

  -- nvim-lspconfig  语言服务器的配置
  use({
    'neovim/nvim-lspconfig'
  })

  -- Autocompletion plugin 自动补全插件
  use({
    'hrsh7th/nvim-cmp',
  })

  -- 
  use({
    'hrsh7th/cmpp-buffer'
  })

  -- LSP source for nvim-cmp lsp使用与自动补全
  use({
    'hrsh7th/cmp-nvim-lsp'
  })

  -- 代码注释功能
  use {
    'numToStr/Comment.nvim'
  }

  -- 文件浏览器, 图标
  use({
    'kyazdani42/nvim-tree.lua'
  })

  -- 浏览器图标
  use({
    'kyazdani42/nvim-web-devicons'
  })

  -- 多文件打开
  use({
    'akinsho/bufferline.nvim'
  })

  -- 状态栏 
  use ({
    'nvim-lualine/lualine.nvim'
  })

  -- 终端
  use ({
    'akinsho/toggleterm.nvim'
  })

  -- 主题
  use({
    'projekt0n/github-nvim-theme'
  })

  -- git 插件，显示改动
  use({
    'lewis6991/gitsigns.nvim'
  })

end)