

return {
  -- 只剩文件树窗口时也保持打开
  close_if_last_window = false,
  sources = {
    "filesystem",
    "git_status",
  },
  source_selector = {
	winbar = true
  },
  filesystem = {
    -- 由 neo-tree 接管 netrw，并默认打开
    hijack_netrw_behavior = "open_default",
    -- 监听文件变化，外部改动会自动刷新
    use_libuv_file_watcher = true,
    -- 显示隐藏文件，但始终隐藏 .git，并跟随当前编辑的文件
    filtered_items = {
      hide_dotfiles = false,
      hide_gitignored = false,
      never_show = { ".git" },
    },
    follow_current_file = { enabled = true },
  },
  window = {
    position = "left",
    width = 30,
    mappings = {
      -- 空格是 leader 键，避免误触文件树的默认映射
      ["<space>"] = "none",
      ["<C-b>"] = function()
        require("plugins.neo-tree.actions").toggle()
      end,
      ["<C-S-b>"] = function()
        require("plugins.neo-tree.actions").switch_focus()
      end,
    },
  },
}
