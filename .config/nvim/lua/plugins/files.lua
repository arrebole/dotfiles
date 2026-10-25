local M = {}
local api = vim.api

function M.write(path, content)
  local fd = assert(vim.uv.fs_open(path, "w", 384))
  local written, err = vim.uv.fs_write(fd, content, 0)
  vim.uv.fs_close(fd)
  assert(written, err)
end

function M.read(path)
  local fd = vim.uv.fs_open(path, "r", 384)
  if not fd then return "" end
  local content = vim.uv.fs_read(fd, vim.uv.fs_fstat(fd).size, 0)
  vim.uv.fs_close(fd)
  return content or ""
end

function M.editor(preferred)
  local function valid(win)
    return win and api.nvim_win_is_valid(win) and api.nvim_win_get_config(win).relative == ""
      and (vim.bo[api.nvim_win_get_buf(win)].buftype == "" or vim.bo[api.nvim_win_get_buf(win)].filetype == "dashboard")
  end
  if valid(preferred) then return preferred end
  if valid(api.nvim_get_current_win()) then return api.nvim_get_current_win() end
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if valid(win) then return win end
  end
  vim.cmd("botright new")
  return api.nvim_get_current_win()
end

function M.current(win)
  local buf = api.nvim_win_get_buf(win or M.editor())
  if vim.bo[buf].filetype == "dashboard" then return vim.fn.getcwd() end
  local name = api.nvim_buf_get_name(buf)
  return name ~= "" and name or vim.fn.getcwd()
end

function M.directory(path)
  path = vim.fs.abspath(path or vim.fn.getcwd())
  return vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
end

function M.project(win)
  local dir = M.directory(M.current(win))
  if vim.fn.executable("git") == 1 then
    local result = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait(2000)
    if result.code == 0 then return vim.trim(result.stdout) end
  end
  return vim.fn.getcwd()
end

function M.open(paths, win)
  local buffers = {}
  for _, path in ipairs(paths) do
    if vim.fn.filereadable(path) == 1 then
      local buf = vim.fn.bufadd(path)
      vim.bo[buf].buflisted = true
      buffers[#buffers + 1] = buf
    end
  end
  if #buffers == 0 then return end
  win = M.editor(win)
  -- 保留旧缓冲区及其未保存内容；文件名不拼接成 Ex 命令。
  local ok, err = pcall(api.nvim_win_set_buf, win, buffers[1])
  if not ok then vim.notify(err, vim.log.levels.ERROR); return end
  api.nvim_set_current_win(win)
end

return M
