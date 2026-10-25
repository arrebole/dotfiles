local M = {}
local api = vim.api
local ns = api.nvim_create_namespace("LocalCmdpal")
local defaults = { width = 72, max_height = 8, row_ratio = 0.3, border = "rounded" }
local options = vim.deepcopy(defaults)
local state = { levels = {}, block = {}, attached = false }

local function highlights()
  api.nvim_set_hl(0, "CmdpalNormal", { link = "NormalFloat", default = true })
  api.nvim_set_hl(0, "CmdpalBorder", { link = "FloatBorder", default = true })
  api.nvim_set_hl(0, "CmdpalTitle", { link = "Title", default = true })
  api.nvim_set_hl(0, "CmdpalPrompt", { link = "DiagnosticInfo", default = true })
end

local function text(content)
  local chunks = {}
  for _, chunk in ipairs(content) do chunks[#chunks + 1] = chunk[2] end
  return table.concat(chunks)
end

local function close()
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

local function active()
  local level = 0
  for candidate in pairs(state.levels) do level = math.max(level, candidate) end
  return state.levels[level]
end

local function buffer()
  if state.buf and api.nvim_buf_is_valid(state.buf) then return state.buf end
  state.buf = api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "hide"
  vim.bo[state.buf].swapfile = false
  vim.bo[state.buf].undolevels = -1
  vim.b[state.buf].miniindentscope_disable = true
  vim.bo[state.buf].filetype = "cmdpal"
  return state.buf
end

local function render()
  local cmd = active()
  if not cmd then
    close()
    return
  end

  local width = math.max(1, math.min(options.width, vim.o.columns - 4))
  local max_height = math.max(1, math.min(options.max_height, vim.o.lines - 6))
  local lines = {}
  for _, content in ipairs(state.block) do
    lines[#lines + 1] = vim.fn.strtrans(text(content))
  end

  local prompt = cmd.firstc .. cmd.prompt .. string.rep(" ", cmd.indent)
  local prompt_lines = vim.split(prompt, "\n", { plain = true })
  for i = 1, #prompt_lines - 1 do lines[#lines + 1] = vim.fn.strtrans(prompt_lines[i]) end
  local prefix = vim.fn.strtrans(prompt_lines[#prompt_lines])
  local value = text(cmd.content)
  local pos = math.min(cmd.pos, #value)
  local before = vim.fn.strtrans(value:sub(1, pos))
  local after = value:sub(pos + 1)
  if cmd.special then
    if not cmd.special.shift then after = after:gsub("^[%z\1-\127\194-\244][\128-\191]*", "", 1) end
    after = cmd.special.char .. after
  end
  -- 末尾留一格，使空命令和行尾都有可见的原生光标位置。
  lines[#lines + 1] = prefix .. before .. vim.fn.strtrans(after) .. " "
  while #lines > max_height do table.remove(lines, 1) end

  local buf = buffer()
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if #prefix > 0 then
    api.nvim_buf_set_extmark(buf, ns, #lines - 1, 0, {
      end_col = #prefix, hl_group = "CmdpalPrompt",
    })
  end

  local title = cmd.firstc == ":" and " Command Center "
    or (cmd.firstc == "/" or cmd.firstc == "?") and " Search "
    or cmd.firstc == "=" and " Expression " or " Input "
  local config = {
    relative = "editor",
    row = math.max(0, math.floor((vim.o.lines - #lines - 2) * options.row_ratio)),
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
    width = width,
    height = #lines,
    style = "minimal",
    border = options.border,
    title = { { title, "CmdpalTitle" } },
    title_pos = "center",
    focusable = false,
    mouse = false,
    noautocmd = true,
    zindex = 200,
    -- Neovim 0.12 将原生命令行补全菜单和光标定位到这个窗口。
    _cmdline_offset = 0,
  }
  if not state.win or not api.nvim_win_is_valid(state.win) then
    state.win = api.nvim_open_win(buf, false, config)
    vim.wo[state.win].eventignorewin = "all"
    vim.wo[state.win].wrap = false
    vim.wo[state.win].sidescrolloff = 4
    vim.wo[state.win].winblend = 0
    vim.wo[state.win].winhighlight = "Normal:CmdpalNormal,FloatBorder:CmdpalBorder,Search:None,IncSearch:None"
  else
    api.nvim_win_set_config(state.win, config)
  end
  api.nvim_win_set_cursor(state.win, { #lines, #prefix + #before })
end

local handlers = {}

function handlers.cmdline_show(content, pos, firstc, prompt, indent, level)
  state.levels[level] = {
    content = content, pos = pos, firstc = firstc,
    prompt = type(prompt) == "string" and prompt or "", indent = indent,
  }
end

function handlers.cmdline_pos(pos, level)
  if state.levels[level] then state.levels[level].pos = pos end
end

function handlers.cmdline_special_char(char, shift, level)
  if state.levels[level] then state.levels[level].special = { char = char, shift = shift } end
end

function handlers.cmdline_hide(level)
  state.levels[level] = nil
end

function handlers.cmdline_block_show(lines) state.block = vim.deepcopy(lines) end
function handlers.cmdline_block_append(line) state.block[#state.block + 1] = line end
function handlers.cmdline_block_hide() state.block = {} end

local function dispatch(event, ...)
  handlers[event](...)
  render()
  -- 更新真实光标，避免命令输入期间光标仍留在编辑窗口。
  api.nvim__redraw({ flush = true, cursor = true, win = state.win })
end

function M.setup(opts)
  if vim.fn.has("nvim-0.12") == 0 then
    error("cmdpal requires Neovim 0.12 or newer")
  end
  options = vim.tbl_extend("force", defaults, opts or {})
  highlights()
  if state.attached then vim.ui_detach(ns) end
  state.levels, state.block = {}, {}
  close()
  vim.ui_attach(ns, { ext_cmdline = true }, function(event, ...)
    if not handlers[event] then return end
    if vim.in_fast_event() then
      local args = { ... }
      vim.schedule(function() dispatch(event, unpack(args)) end)
    else
      dispatch(event, ...)
    end
    return true
  end)
  state.attached = true

  vim.o.cmdheight = 0
  vim.o.laststatus = 3
  vim.o.showcmd = false
  vim.o.wildmenu = true
  vim.opt.wildoptions:append("pum")
  vim.o.wildmode = "full"

  local group = api.nvim_create_augroup("LocalCmdpal", { clear = true })
  api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function() if active() then render() end end,
  })
  api.nvim_create_autocmd("TabEnter", {
    group = group,
    callback = function() vim.o.cmdheight = 0 end,
  })
end

return M
