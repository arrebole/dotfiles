local M = {}

-- 点击标签时回到普通编辑窗口，避免替换浮动终端。
local function focus_editor()
  if vim.api.nvim_win_get_config(0).relative == "" and (vim.bo.buftype == "" or vim.bo.filetype == "dashboard") then
    return true
  end

  local function is_editor(win)
    return vim.api.nvim_win_is_valid(win)
      and vim.api.nvim_win_get_config(win).relative == ""
      and (vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" or vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dashboard")
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
    vim.cmd("botright new")
    vim.api.nvim_set_current_buf(bufnr)
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
      -- 最后一个文件关闭后保留编辑窗口，显示空白缓冲区。
      replacement = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_win_set_buf(win, replacement)
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
