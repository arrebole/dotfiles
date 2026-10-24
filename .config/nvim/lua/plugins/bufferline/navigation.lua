local M = {}

-- 从文件树切换 buffer 时，先回到编辑窗口，避免替换文件树。
local function focus_editor()
  if vim.bo.filetype ~= "neo-tree" then
    return true
  end

  local function is_editor(win)
    return vim.api.nvim_win_is_valid(win)
      and vim.api.nvim_win_get_config(win).relative == ""
      and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
  end

  local previous = vim.fn.win_getid(vim.fn.winnr("#"))
  if is_editor(previous) then
    vim.api.nvim_set_current_win(previous)
    return true
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor(win) then
      vim.api.nvim_set_current_win(win)
      return true
    end
  end

  return false
end

function M.open(bufnr)
  if focus_editor() then
    vim.api.nvim_set_current_buf(bufnr)
  else
    -- 直接显示目标文件，不先创建空白 buffer。
    local tree = vim.api.nvim_get_current_win()
    vim.api.nvim_open_win(bufnr, true, { split = "right", win = tree })
    vim.api.nvim_win_set_width(tree, require("plugins.neo-tree.config").window.width)
  end
end

function M.cycle(direction)
  local bufferline = require("bufferline")
  if focus_editor() then
    bufferline.cycle(direction)
  else
    local elements = bufferline.get_elements().elements
    local target = elements[direction > 0 and 1 or #elements]
    if target then
      M.open(target.id)
    end
  end
end

function M.close(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.bo[bufnr].modified then
    vim.notify("文件有未保存的修改，请保存后再关闭。", vim.log.levels.WARN)
    return
  end

  local current = vim.api.nvim_get_current_win()
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(buffers, function(a, b)
    return a.lastused > b.lastused
  end)
  local replacement
  for _, buf in ipairs(buffers) do
    if buf.bufnr ~= bufnr
      and vim.bo[buf.bufnr].buftype == ""
      and (buf.name ~= "" or vim.bo[buf.bufnr].modified)
      and vim.fn.isdirectory(buf.name) == 0
    then
      replacement = buf.bufnr
      break
    end
  end

  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    if replacement then
      -- 先替换窗口里的内容，防止 bdelete 连同窗口一起关闭。
      vim.api.nvim_win_set_buf(win, replacement)
    else
      -- 最后一个文件关闭后，只保留该 tab 的文件树，不创建空白文件。
      local tab = vim.api.nvim_win_get_tabpage(win)
      for _, other in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if other ~= win
          and vim.api.nvim_win_get_config(other).relative == ""
          and vim.bo[vim.api.nvim_win_get_buf(other)].filetype == "neo-tree"
        then
          vim.api.nvim_win_close(win, false)
          break
        end
      end
    end
  end

  local ok, err = pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
  if not ok then
    vim.notify(err, vim.log.levels.ERROR)
  end
  if vim.api.nvim_win_is_valid(current) then
    vim.api.nvim_set_current_win(current)
  end
end

return M
