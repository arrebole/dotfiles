return {
  options = {
    mode = "buffers",
    diagnostics = "nvim_lsp",
    separator_style = "thin",
    always_show_bufferline = true,
    show_close_icon = false,
    -- 隐藏遗留的空白 buffer；正在编辑或含未保存内容的 buffer 仍显示。
    custom_filter = function(bufnr)
      local unused = vim.api.nvim_buf_get_name(bufnr) == ""
        and not vim.bo[bufnr].modified
        and vim.api.nvim_buf_line_count(bufnr) == 1
        and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
      return not unused or #vim.fn.win_findbuf(bufnr) > 0
    end,
    left_mouse_command = function(bufnr)
      require("plugins.bufferline.navigation").open(bufnr)
    end,
    -- 关闭标签时保留编辑窗口和焦点，同时保护未保存的修改。
    close_command = function(bufnr)
      require("plugins.bufferline.navigation").close(bufnr)
    end,
    right_mouse_command = function(bufnr)
      require("plugins.bufferline.navigation").close(bufnr)
    end,
  },
}
