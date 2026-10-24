local M = {}
local sessions = {}
local options = { height = 12 }

local function valid_window(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function visible(session)
  return valid_window(session.win) and vim.api.nvim_win_get_buf(session.win) == session.buf
end

local function split_anchor()
  local function is_editor(win)
    return valid_window(win)
      and vim.api.nvim_win_get_config(win).relative == ""
      and vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "neo-tree"
  end
  local current = vim.api.nvim_get_current_win()
  if is_editor(current) then return current end
  local previous = vim.fn.win_getid(vim.fn.winnr("#"))
  if is_editor(previous) then return previous end
  local tree
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_editor(win) then return win end
    if vim.api.nvim_win_get_config(win).relative == "" then tree = win end
  end
  return tree or current
end

local function hide(session)
  if not visible(session) then return end
  local current = vim.api.nvim_get_current_win()
  local target = session.origin
  if not valid_window(target) or vim.api.nvim_win_get_tabpage(target) ~= session.tab then
    target = nil
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(session.tab)) do
      if win ~= session.win and vim.api.nvim_win_get_config(win).relative == "" then
        target = win
        if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then break end
      end
    end
  end

  if target then
    vim.api.nvim_win_close(session.win, false)
    if current == session.win then vim.api.nvim_set_current_win(target) end
  else
    -- 用户已关闭其余窗口时，Neovim 必须保留一个窗口。
    vim.api.nvim_win_set_buf(session.win, vim.api.nvim_create_buf(true, false))
  end
  session.win = nil
end

local function discard(session)
  if sessions[session.tab] ~= session then return end
  if visible(session) then hide(session) end
  if vim.api.nvim_buf_is_valid(session.buf) then
    vim.api.nvim_buf_delete(session.buf, { force = true })
  end
  sessions[session.tab] = nil
end

function M.toggle()
  local tab = vim.api.nvim_get_current_tabpage()
  local session = sessions[tab]
  if session and visible(session) then
    hide(session)
    return
  end
  if session and (not vim.api.nvim_buf_is_valid(session.buf) or session.exited) then
    discard(session)
    session = nil
  end
  local fresh = not session
  if fresh then
    session = { tab = tab, buf = vim.api.nvim_create_buf(false, true) }
    sessions[tab] = session
    vim.bo[session.buf].bufhidden = "hide"
    vim.bo[session.buf].swapfile = false
  end

  session.origin = vim.api.nvim_get_current_win()
  local anchor = split_anchor()
  local tree_only = vim.bo[vim.api.nvim_win_get_buf(anchor)].filetype == "neo-tree"
  local split = { split = tree_only and "right" or "below", win = anchor }
  if not tree_only then
    split.height = math.max(3, math.min(options.height, math.floor(vim.api.nvim_win_get_height(anchor) * 0.4)))
  end
  -- 只分割编辑窗口；只有文件树时直接在其右侧显示终端。
  session.win = vim.api.nvim_open_win(session.buf, true, split)
  if tree_only then
    vim.api.nvim_win_set_width(anchor, require("plugins.neo-tree.config").window.width)
  end
  if fresh then
    local ok, job = pcall(vim.fn.jobstart, options.shell or vim.o.shell, {
      term = true,
      cwd = vim.fn.getcwd(),
      on_exit = function()
        session.exited = true
        vim.schedule(function()
          if vim.v.exiting == vim.NIL then discard(session) end
        end)
      end,
    })
    if not ok or job <= 0 then
      discard(session)
      vim.notify("无法启动终端：" .. tostring(job), vim.log.levels.ERROR)
      return
    end
    session.job = job
    vim.bo[session.buf].buflisted = false
    vim.bo[session.buf].filetype = "terminal"
  end
  vim.wo[session.win].number = false
  vim.wo[session.win].relativenumber = false
  vim.wo[session.win].signcolumn = "no"
  vim.wo[session.win].winfixheight = true
  vim.cmd("startinsert")
end

function M.setup(opts)
  options = vim.tbl_extend("force", { height = 12 }, opts or {})
  for _, key in ipairs({ "<C-`>", "<C-~>" }) do
    vim.keymap.set("n", key, M.toggle, { silent = true, desc = "打开或隐藏终端" })
    vim.keymap.set("i", key, "<Esc><Cmd>lua require('plugins.terminal').toggle()<CR>", {
      silent = true, desc = "打开或隐藏终端",
    })
    vim.keymap.set("t", key, "<C-\\><C-n><Cmd>lua require('plugins.terminal').toggle()<CR>", {
      silent = true, desc = "隐藏终端并返回原窗口",
    })
  end
  vim.api.nvim_create_user_command("TerminalToggle", M.toggle, { desc = "打开或隐藏终端", force = true })
  local group = vim.api.nvim_create_augroup("LocalTerminal", { clear = true })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      vim.schedule(function()
        for tab, session in pairs(sessions) do
          if not vim.api.nvim_tabpage_is_valid(tab) then
            if session.job then vim.fn.jobstop(session.job) end
            discard(session)
          end
        end
      end)
    end,
  })
end

return M
