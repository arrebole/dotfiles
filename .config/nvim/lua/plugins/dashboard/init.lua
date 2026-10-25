-- 参考 dashboard-nvim 的启动页设计，本地独立实现。
local M = {}
local api = vim.api
local ns = api.nvim_create_namespace("LocalDashboard")
local history = require("plugins.dashboard.history")
local options, state, stdin_seen
local window_options = {
  number = false, relativenumber = false, signcolumn = "no", foldcolumn = "0",
  cursorline = true, cursorcolumn = false, wrap = false, list = false,
  spell = false, colorcolumn = "", winbar = "", statuscolumn = "",
}

local function highlights()
  for name, link in pairs({ Muted = "Comment", Section = "Directory" }) do
    api.nvim_set_hl(0, "Dashboard" .. name, { link = link, default = true })
  end
end

local function restore()
  if not state then return end
  if state.chrome then
    vim.o.laststatus, vim.o.showtabline = state.chrome.laststatus, state.chrome.showtabline
    state.chrome = nil
  end
  for win, saved in pairs(state.windows) do
    if api.nvim_win_is_valid(win) then
      for name, value in pairs(saved) do vim.wo[win][name] = value end
    end
  end
  state.windows = {}
end

local function decorate(win)
  if not state.chrome then state.chrome = { laststatus = vim.o.laststatus, showtabline = vim.o.showtabline } end
  vim.o.laststatus, vim.o.showtabline = 0, 0
  if not state.windows[win] then
    local saved = {}
    for name in pairs(window_options) do saved[name] = vim.wo[win][name] end
    state.windows[win] = saved
  end
  for name, value in pairs(window_options) do vim.wo[win][name] = value end
end

local function fit(text, width)
  text = tostring(text):gsub("[%c]", " ")
  if vim.fn.strdisplaywidth(text) <= width then return text end
  while vim.fn.strdisplaywidth(text) > math.max(0, width - 1) do
    text = vim.fn.strcharpart(text, 0, vim.fn.strchars(text) - 1)
  end
  return text .. "…"
end

function M.open_directory(path)
  if vim.fn.isdirectory(path) ~= 1 then
    vim.notify("目录已不存在：" .. path, vim.log.levels.WARN)
    return
  end
  api.nvim_cmd({ cmd = "cd", args = { path }, magic = { file = false } }, {})
  history.remember(path)
  require("plugins.yazi").open(path)
end

local function render()
  if not state or not api.nvim_buf_is_valid(state.buf) then return end
  local win = vim.fn.bufwinid(state.buf)
  if win == -1 then return end
  local width = math.max(8, math.min(options.width, api.nvim_win_get_width(win) - 4))
  local height = api.nvim_win_get_height(win)
  local body, groups, rows = {}, {}, {}
  local function add(text, group, action, center)
    text = fit(text, width)
    local padding = math.max(0, math.floor((api.nvim_win_get_width(win) - width) / 2))
    if center then padding = math.max(0, math.floor((api.nvim_win_get_width(win) - vim.fn.strdisplaywidth(text)) / 2)) end
    body[#body + 1] = string.rep(" ", padding) .. text
    groups[#body] = group
    if action then rows[#rows + 1] = { line = #body, action = action, column = padding } end
  end
  add("最近打开的目录", "DashboardSection")
  add("")
  for i = 1, 9 do pcall(vim.keymap.del, "n", tostring(i), { buffer = state.buf }) end
  local paths = history.list()
  local limit = math.min(9, options.recent_limit, math.max(1, height - 6), #paths)
  for i = 1, limit do
    local path = paths[i]
    local action = function() M.open_directory(path) end
    add("[" .. i .. "]  " .. vim.fn.fnamemodify(path, ":~"), nil, action)
    vim.keymap.set("n", tostring(i), action, { buffer = state.buf, silent = true, desc = "打开最近目录" })
  end
  if #paths == 0 then add("暂无记录", "DashboardMuted") end
  add("")
  add("j/k 选择 · Enter 打开", "DashboardMuted", nil, true)
  local top = math.max(0, math.floor((height - #body) / 2))
  local lines = {}
  for _ = 1, top do lines[#lines + 1] = "" end
  vim.list_extend(lines, body)
  vim.bo[state.buf].modifiable = true
  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
  for line, group in pairs(groups) do
    api.nvim_buf_set_extmark(state.buf, ns, top + line - 1, 0, { end_col = #body[line], hl_group = group })
  end
  for _, row in ipairs(rows) do row.line = row.line + top end
  state.rows = rows
  state.selected = math.max(1, math.min(state.selected or 1, #rows))
  local selected = rows[state.selected]
  if selected then api.nvim_win_set_cursor(win, { selected.line, selected.column }) end
end

local function move(direction)
  if not state or #state.rows == 0 then return end
  state.selected = (state.selected - 1 + direction) % #state.rows + 1
  local row = state.rows[state.selected]
  api.nvim_win_set_cursor(0, { row.line, row.column })
end

local function activate()
  if not state then return end
  local line = api.nvim_win_get_cursor(0)[1]
  for _, row in ipairs(state.rows) do
    if row.line == line then return row.action() end
  end
end

function M.open()
  if state and api.nvim_buf_is_valid(state.buf) then
    local win = vim.fn.bufwinid(state.buf)
    if win ~= -1 then api.nvim_set_current_win(win); return end
  end
  local previous = api.nvim_get_current_buf()
  local win = require("plugins.files").editor()
  local buf = api.nvim_create_buf(false, true)
  state = { buf = buf, windows = {}, rows = {}, selected = 1 }
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].undolevels = -1
  vim.b[buf].miniindentscope_disable = true
  vim.bo[buf].filetype = "dashboard"
  api.nvim_buf_set_name(buf, "dashboard://start")
  api.nvim_win_set_buf(win, buf)
  api.nvim_set_current_win(win)
  decorate(win)
  vim.keymap.set("n", "q", "<Cmd>confirm qall<CR>", { buffer = buf, silent = true, desc = "退出" })
  for key, direction in pairs({ j = 1, k = -1, ["<Down>"] = 1, ["<Up>"] = -1, ["<Tab>"] = 1, ["<S-Tab>"] = -1 }) do
    vim.keymap.set("n", key, function() move(direction) end, { buffer = buf, silent = true })
  end
  vim.keymap.set("n", "<CR>", activate, { buffer = buf, silent = true, desc = "打开所选入口" })
  vim.keymap.set("n", "<2-LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse.winid == api.nvim_get_current_win() and mouse.line > 0 then
      api.nvim_win_set_cursor(0, { mouse.line, 0 }); activate()
    end
  end, { buffer = buf, silent = true })
  render()
  -- 启动时留下的空白 buffer 不进入最近文件和标签栏。
  if api.nvim_buf_is_valid(previous) and previous ~= buf and vim.bo[previous].buftype == ""
    and not vim.bo[previous].modified and api.nvim_buf_get_name(previous) == ""
    and #vim.fn.win_findbuf(previous) == 0 then
    api.nvim_buf_delete(previous, { force = false })
  end
end

function M.setup(opts)
  options = vim.tbl_extend("force", { width = 72, recent_limit = 9 }, opts or {})
  history.setup(options.history_file)
  highlights()
  local group = api.nvim_create_augroup("LocalDashboard", { clear = true })
  api.nvim_create_user_command("Dashboard", M.open, { desc = "打开本地启动面板" })
  api.nvim_create_autocmd("StdinReadPre", { group = group, callback = function() stdin_seen = true end })
  api.nvim_create_autocmd("VimEnter", { group = group, once = true, callback = function()
    vim.schedule(function()
      if not stdin_seen and #api.nvim_list_uis() > 0 then
        local entry = vim.fn.argv(0)
        if type(entry) == "string" and entry ~= "" then
          entry = vim.fs.abspath(entry)
          history.remember(vim.fn.isdirectory(entry) == 1 and entry or history.project(entry))
        elseif vim.v.this_session ~= "" then history.remember(vim.fn.getcwd()) end
      end
      if stdin_seen or vim.fn.argc() ~= 0 or #api.nvim_list_uis() == 0 or vim.v.this_session ~= "" then return end
      if #api.nvim_list_wins() ~= 1 or vim.bo.buftype ~= "" or vim.bo.modified then return end
      if api.nvim_buf_get_name(0) ~= "" or api.nvim_buf_line_count(0) ~= 1
        or api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= "" then return end
      M.open()
    end)
  end })
  api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, { group = group, callback = function(event)
    if state and event.buf == state.buf then restore() end
  end })
  api.nvim_create_autocmd("BufEnter", { group = group, callback = function(event)
    if state and event.buf == state.buf then decorate(api.nvim_get_current_win()); render() end
  end })
  api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(event)
    if state and event.buf == state.buf then restore(); state = nil end
  end })
  api.nvim_create_autocmd({ "VimResized", "WinResized" }, { group = group, callback = render })
  api.nvim_create_autocmd("DirChanged", { group = group, callback = function()
    if #api.nvim_list_uis() > 0 then history.remember(vim.fn.getcwd()) end
    render()
  end })
  api.nvim_create_autocmd("BufReadPost", { group = group, callback = function(event)
    if #api.nvim_list_uis() > 0 and vim.bo[event.buf].buftype == "" and vim.fn.filereadable(event.file) == 1 then
      history.remember(history.project(event.file))
    end
  end })
  api.nvim_create_autocmd("User", { group = group, pattern = "LocalDirectoryOpened", callback = function(event)
    history.remember(event.data.path)
    render()
  end })
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = function() highlights(); render() end })
end

return M
