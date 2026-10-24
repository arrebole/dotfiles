local M = {}

local function tree_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree"
      and vim.api.nvim_win_get_config(win).relative == ""
    then
      return win
    end
  end
end

function M.toggle()
  local current = vim.api.nvim_get_current_win()
  local command = require("neo-tree.command")
  if tree_window() then
    command.execute({ action = "close", position = "left" })
  else
    command.execute({ action = "show", source = "filesystem", position = "left" })
  end
  -- 打开文件树或从编辑区关闭文件树时，保留原窗口焦点。
  if vim.api.nvim_win_is_valid(current) then
    vim.api.nvim_set_current_win(current)
  end
end

function M.switch_focus()
  local tree = tree_window()
  if not tree then
    require("neo-tree.command").execute({
      action = "focus",
      source = "filesystem",
      position = "left",
    })
    return
  end
  if vim.api.nvim_get_current_win() ~= tree then
    vim.api.nvim_set_current_win(tree)
    return
  end

  local function is_editor(win)
    return vim.api.nvim_win_is_valid(win)
      and vim.api.nvim_win_get_config(win).relative == ""
      and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
  end
  local previous = vim.fn.win_getid(vim.fn.winnr("#"))
  if is_editor(previous) then
    vim.api.nvim_set_current_win(previous)
    return
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor(win) then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
  -- 没有编辑窗口时保持文件树焦点，不创建空白编辑区。
end

return M
