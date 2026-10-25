return {
  cmdline = { enabled = true, view = "cmdline_popup" },
  messages = {
    enabled = true,
    view = "mini",
    view_error = "mini",
    view_warn = "mini",
  },
  notify = { enabled = true, view = "mini" },
  lsp = {
    message = { view = "mini" },
    -- 保留 Neovim 原来的文档和签名提示行为。
    hover = { enabled = false },
    signature = { enabled = false },
  },
  views = {
    cmdline_popup = {
      position = { row = "30%", col = "50%" },
      size = { width = 72, height = "auto" },
      border = { style = "rounded" },
    },
    mini = {
      timeout = 5000,
      win_options = { winblend = 10 },
    },
  },
}
