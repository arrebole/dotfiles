

return {
  -- 只剩文件树窗口时也保持打开
  close_if_last_window = false,
  sources = {
    "filesystem",
    "buffers",
    "git_status",
  },
  filesystem = {
    -- 由 neo-tree 接管 netrw，并在独立窗口中打开目录
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
    components = {
      -- 项目名称不显示全路径
      name = function(config, node, state)
        local result = require("neo-tree.sources.common.components").name(config, node, state)

        -- 根目录只显示最后一级目录名
        if node:get_depth() == 1 and node.type == "directory" then
          local path = node.path or node:get_id()
          local name = vim.fn.fnamemodify(path, ":t")
          result.text = name ~= "" and name or path
        end

        return result
      end,
    },
  },
  window = {
    width = 30,
    mappings = {
      -- 空格是 leader 键，避免误触文件树的默认映射
      ["<space>"] = "none",
      -- 在文件浏览器中也使用 Ctrl+B 关闭窗口
      ["<C-b>"] = "close_window",
    },
  },
}