-- 本地维护的 LazyGit 终端集成，命令设计参考 kdheepak/lazygit.nvim。
local M = {}
local api = vim.api
local defaults = { executable = "lazygit", width = 0.9, height = 0.9, border = "rounded", winblend = 0, args = {} }
local options = vim.deepcopy(defaults)
local session

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.WARN, { title = "LazyGit" })
end

local function geometry()
  local columns, lines = vim.o.columns, vim.o.lines - vim.o.cmdheight - 2
  local width = math.max(1, math.min(columns - 2, math.floor(columns * options.width)))
  local height = math.max(1, math.min(lines - 2, math.floor(lines * options.height)))
  return {
    relative = "editor", style = "minimal", border = options.border,
    width = width, height = height,
    col = math.max(0, math.floor((columns - width - 2) / 2)),
    row = math.max(0, math.floor((lines - height) / 2)),
    title = " LazyGit · Ctrl-g 隐藏/恢复 ", title_pos = "center",
  }
end

local function refresh()
  -- checktime 会保留尚未保存的编辑，并按 Neovim 原有规则处理外部修改。
  vim.cmd("checktime")
  -- Gitsigns 自身监听 Git 索引和文件变化，无需重置其渲染器。
  vim.cmd("redrawstatus")
end

local function restore(current)
  if current.previous and api.nvim_win_is_valid(current.previous) then
    api.nvim_set_current_win(current.previous)
  end
end

function M.hide()
  if not session then return end
  local current = session
  if current.win and api.nvim_win_is_valid(current.win) then
    local focused = api.nvim_get_current_win() == current.win
    vim.cmd("stopinsert")
    api.nvim_win_close(current.win, true)
    current.win = nil
    if focused then restore(current) end
  end
  vim.schedule(refresh)
end

function M.close()
  if not session then return end
  local current = session
  M.hide()
  session = nil
  -- 由 Neovim 删除终端时统一停止任务，避免重复关闭 ConPTY。
  if api.nvim_buf_is_valid(current.buf) then
    api.nvim_buf_delete(current.buf, { force = true })
  end
end

local function show(current)
  if api.nvim_get_current_win() ~= current.win then
    current.previous = api.nvim_get_current_win()
  end
  if current.win and api.nvim_win_is_valid(current.win) then
    api.nvim_set_current_win(current.win)
  else
    current.win = api.nvim_open_win(current.buf, true, geometry())
    vim.wo[current.win].winblend = options.winblend
    vim.wo[current.win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
  end
  if not current.exited then vim.cmd("startinsert") end
end

local function file_path()
  local path = api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= "" or path == "" then
    notify("当前缓冲区不是文件，请使用 :LazyGit 打开工作目录的仓库。")
    return
  end
  return path
end

local function root(directory)
  if vim.fn.executable("git") ~= 1 then notify("找不到 git，请安装并加入 PATH。") return end
  local result = vim.system({ "git", "-C", directory, "rev-parse", "--show-toplevel" }, { text = true }):wait(3000)
  if result.code ~= 0 then
    notify("无法定位 Git 仓库：" .. directory .. "\n" .. vim.trim(result.stderr or ""))
    return
  end
  return vim.trim(result.stdout)
end

function M.open(opts)
  opts = opts or {}
  if session and api.nvim_buf_is_valid(session.buf) then
    show(session)
    return
  end
  session = nil
  if vim.fn.executable(options.executable) ~= 1 then
    notify("找不到 lazygit；Windows 可运行 scoop install lazygit，或在 config.lua 设置 executable。")
    return
  end
  local path
  if opts.current_file or opts.filter then
    path = file_path()
    if not path then return end
  end
  local directory = opts.cwd or (path and vim.fs.dirname(path)) or vim.fn.getcwd()
  local repo = root(directory)
  if not repo then return end
  local command = { options.executable }
  vim.list_extend(command, options.args)
  if opts.log then command[#command + 1] = "log" end
  if opts.filter then
    vim.list_extend(command, { "--filter", vim.fs.relpath(repo, path) or path })
  end

  local current = { buf = api.nvim_create_buf(false, true), cwd = repo }
  session = current
  vim.bo[current.buf].bufhidden = "hide"
  vim.bo[current.buf].swapfile = false
  vim.b[current.buf].miniindentscope_disable = true
  show(current)
  local ok, job = pcall(vim.fn.jobstart, command, {
    cwd = repo, term = true,
    on_exit = function(_, code)
      vim.schedule(function()
        if session ~= current then return end
        current.exited = true
        if code == 0 then
          M.close()
        else
          if current.win and api.nvim_get_current_win() == current.win then vim.cmd("stopinsert") end
          refresh()
          notify("LazyGit 退出码 " .. code .. "；终端输出已保留，按 q 关闭。", vim.log.levels.ERROR)
        end
      end)
    end,
  })
  if not ok or job <= 0 then
    M.close()
    notify("启动 LazyGit 失败：" .. tostring(job), vim.log.levels.ERROR)
    return
  end
  current.job = job
  vim.bo[current.buf].filetype = "lazygit"
  vim.keymap.set({ "n", "t" }, "<C-g>", M.hide, { buffer = current.buf, desc = "隐藏 LazyGit" })
  vim.keymap.set("n", "q", M.close, { buffer = current.buf, desc = "关闭 LazyGit" })
  api.nvim_create_autocmd("BufWipeout", {
    buffer = current.buf, once = true,
    callback = function()
      if session == current then
        session = nil
        vim.schedule(refresh)
      end
    end,
  })
end

function M.toggle()
  if session and session.win and api.nvim_win_is_valid(session.win)
    and api.nvim_get_current_win() == session.win then
    M.hide()
  else
    M.open()
  end
end

function M.setup(opts)
  options = vim.tbl_extend("force", defaults, opts or {})
  for _, key in ipairs({ "width", "height" }) do
    assert(type(options[key]) == "number" and options[key] > 0 and options[key] <= 1, key .. " must be in (0, 1]")
  end
  local function command(name, callback, desc, extra)
    api.nvim_create_user_command(name, callback, vim.tbl_extend("force", { desc = desc }, extra or {}))
  end
  command("LazyGit", function(args) M.open({ cwd = args.args ~= "" and args.args or nil }) end,
    "打开工作目录或指定目录的 Git 仓库", { nargs = "?", complete = "dir" })
  command("LazyGitCurrentFile", function() M.open({ current_file = true }) end, "打开当前文件的 Git 仓库")
  command("LazyGitLog", function() M.open({ log = true }) end, "打开仓库提交历史")
  command("LazyGitFilterCurrentFile", function() M.open({ filter = true }) end, "打开当前文件的 Git 历史")
  command("LazyGitClose", M.close, "关闭 LazyGit 会话")
  local group = api.nvim_create_augroup("LocalLazyGit", { clear = true })
  api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if session and session.win and api.nvim_win_is_valid(session.win) then
        api.nvim_win_set_config(session.win, geometry())
      end
    end,
  })
end

return M
