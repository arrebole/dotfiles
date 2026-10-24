local M = {}

-- 文件树独占当前 tab 时，仅在有文件可显示时恢复右侧编辑区。
function M.ensure_editor()
  if vim.v.exiting ~= vim.NIL then
    return
  end

  local windows = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
  if #windows ~= 1 then
    return
  end

  local tree = windows[1]
  if vim.bo[vim.api.nvim_win_get_buf(tree)].filetype ~= "neo-tree" then
    return
  end

  -- 恢复最近使用的文件或未保存的内容，忽略未使用的空白 buffer。
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(buffers, function(a, b)
    return a.lastused > b.lastused
  end)
  local target
  for _, buf in ipairs(buffers) do
    if vim.bo[buf.bufnr].buftype == ""
      and vim.bo[buf.bufnr].filetype ~= "neo-tree"
      and (buf.name ~= "" or vim.bo[buf.bufnr].modified)
      and vim.fn.isdirectory(buf.name) == 0
    then
      target = buf.bufnr
      break
    end
  end

  if not target then
    return
  end
  vim.api.nvim_open_win(target, false, { split = "right", win = tree })
  vim.api.nvim_win_set_width(tree, require("plugins.neo-tree.config").window.width)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("NeoTreeKeepEditor", { clear = true })
  -- 以目录启动时，neo-tree 自身也会留下一个空白窗口；启动后收起它。
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      vim.schedule(function()
        local tree, empty
        local windows = vim.tbl_filter(function(win)
          return vim.api.nvim_win_get_config(win).relative == ""
        end, vim.api.nvim_tabpage_list_wins(0))
        for _, win in ipairs(windows) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype == "neo-tree" then
            tree = win
          elseif vim.bo[buf].buftype == ""
            and vim.api.nvim_buf_get_name(buf) == ""
            and not vim.bo[buf].modified
            and vim.api.nvim_buf_line_count(buf) == 1
            and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
          then
            empty = win
          end
        end
        if #windows == 2 and tree and empty then
          local buf = vim.api.nvim_win_get_buf(empty)
          vim.api.nvim_win_close(empty, false)
          if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
            vim.api.nvim_buf_delete(buf, { force = false })
          end
        end
      end)
    end,
  })
  local pending = false
  vim.api.nvim_create_autocmd({ "VimEnter", "TabEnter", "BufWinEnter", "WinClosed" }, {
    group = group,
    callback = function()
      if pending then
        return
      end
      pending = true
      -- 等窗口关闭或文件树初始化完成后再调整布局。
      vim.schedule(function()
        pending = false
        M.ensure_editor()
      end)
    end,
  })
end

return M
