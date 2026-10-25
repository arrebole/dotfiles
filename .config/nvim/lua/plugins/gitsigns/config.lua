return {
  current_line_blame = false,
  preview_config = { border = "rounded" },
  on_attach = function(buf)
    local git = require("gitsigns")
    local function map(mode, key, action, desc)
      vim.keymap.set(mode, key, action, { buffer = buf, silent = true, desc = desc })
    end

    for key, direction in pairs({ ["]h"] = "next", ["[h"] = "prev" }) do
      map("n", key, function() git.nav_hunk(direction) end, "跳转 Git 修改块：" .. direction)
    end
    map("n", "<leader>hs", git.stage_hunk, "暂存或取消暂存修改块")
    map("x", "<leader>hs", function()
      git.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "暂存或取消暂存选中行")
    map("n", "<leader>hr", git.reset_hunk, "还原修改块")
    map("x", "<leader>hr", function()
      git.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "还原选中行")
    map("n", "<leader>hS", git.stage_buffer, "暂存当前文件")
    map("n", "<leader>hp", git.preview_hunk, "预览修改块")
    map("n", "<leader>hb", function() git.blame_line({ full = true }) end, "查看当前行提交")
    map("n", "<leader>hd", git.diffthis, "比较当前文件与暂存区")
    map("n", "<leader>hB", git.toggle_current_line_blame, "切换行内 Git blame")
    map({ "o", "x" }, "ih", git.select_hunk, "选择 Git 修改块")
  end,
}
