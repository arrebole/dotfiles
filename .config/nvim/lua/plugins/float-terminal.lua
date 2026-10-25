-- Yazi/fzf 共用的浮动终端：负责窗口和进程生命周期，业务结果由调用方读取。
local M = {}
local api = vim.api
local sessions = {}

local function geometry(opts)
  local width = math.max(1, math.min(vim.o.columns - 2, math.floor(vim.o.columns * (opts.width or 0.9))))
  local available = vim.o.lines - vim.o.cmdheight - 2
  local height = math.max(1, math.min(available - 2, math.floor(available * (opts.height or 0.85))))
  return {
    relative = "editor", style = "minimal", border = opts.border or "rounded",
    width = width, height = height,
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
    row = math.max(0, math.floor((available - height) / 2)),
    title = " " .. opts.title .. " ", title_pos = "center",
  }
end

function M.focus(id)
  local s = sessions[id]
  if not s then return false end
  if api.nvim_win_is_valid(s.win) then
    api.nvim_set_current_win(s.win)
    vim.cmd("startinsert")
  end
  return true
end

function M.close(id)
  local s = sessions[id]
  if s then s.finish(130, true) end
end

function M.open(id, command, opts)
  if M.focus(id) then return end
  local s = { buf = api.nvim_create_buf(false, true), opts = opts }
  sessions[id] = s
  vim.bo[s.buf].bufhidden = "hide"
  vim.bo[s.buf].swapfile = false
  vim.b[s.buf].miniindentscope_disable = true
  s.win = api.nvim_open_win(s.buf, true, geometry(opts))
  vim.wo[s.win].winblend = 0
  local group = api.nvim_create_augroup("LocalFloat_" .. id, { clear = true })
  local function deliver(code)
    if s.delivered then return end
    s.delivered = true
    vim.schedule(function() opts.on_exit(code, s.cancelled, s.output) end)
  end
  s.finish = function(code, cancelled)
    if s.done then
      if not cancelled then deliver(code) end
      return
    end
    s.done = true
    s.cancelled = cancelled
    sessions[id] = nil
    api.nvim_del_augroup_by_id(group)
    local focused = api.nvim_get_current_win() == s.win
    s.output = api.nvim_buf_is_valid(s.buf) and api.nvim_buf_get_lines(s.buf, 0, -1, false) or {}
    if focused then vim.cmd("stopinsert") end
    if api.nvim_win_is_valid(s.win) then api.nvim_win_close(s.win, true) end
    if api.nvim_buf_is_valid(s.buf) then api.nvim_buf_delete(s.buf, { force = true }) end
    if focused and opts.previous and api.nvim_win_is_valid(opts.previous) then
      api.nvim_set_current_win(opts.previous)
    end
    -- 取消时等进程真正退出后再读/删结果文件，避免 Windows 的文件句柄占用。
    if not cancelled or not s.job then deliver(code) end
  end
  api.nvim_create_autocmd("VimResized", {
    group = group, callback = function()
      if api.nvim_win_is_valid(s.win) then api.nvim_win_set_config(s.win, geometry(opts)) end
    end,
  })
  api.nvim_create_autocmd("WinClosed", {
    group = group, pattern = tostring(s.win), callback = function()
      vim.schedule(function() s.finish(130, true) end)
    end,
  })
  api.nvim_create_autocmd("BufWipeout", {
    group = group, buffer = s.buf, callback = function()
      vim.schedule(function() s.finish(130, true) end)
    end,
  })
  local ok, job = pcall(vim.fn.jobstart, command, {
    cwd = opts.cwd, env = opts.env, term = true,
    on_exit = function(_, code) vim.schedule(function() s.finish(code, false) end) end,
  })
  if not ok or job <= 0 then
    s.finish(-1, false)
    vim.notify("启动 " .. opts.title .. " 失败：" .. tostring(job), vim.log.levels.ERROR)
    return
  end
  s.job = job
  vim.bo[s.buf].filetype = id
  vim.keymap.set("n", "q", function() M.close(id) end, { buffer = s.buf, desc = "关闭 " .. opts.title })
  vim.keymap.set("t", "<C-q>", function() M.close(id) end, { buffer = s.buf, desc = "关闭 " .. opts.title })
  vim.cmd("startinsert")
end

return M
