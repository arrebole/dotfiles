local M = {}

local defaults = {
  path_width = 100,
  details_width = 80,
}
local options = vim.deepcopy(defaults)

-- 文件名等文本不能直接作为 statusline 格式串使用。
local function escape(text)
  return (tostring(text):gsub("[%c]", " "):gsub("%%", "%%%%"))
end

local function color(name, fallback)
  return vim.api.nvim_get_hl(0, { name = name, link = false }).fg or fallback
end

local function highlights()
  local normal = color("Normal", "#cdd6f4")
  vim.api.nvim_set_hl(0, "LocalStatusBase", { fg = normal, bg = "NONE" })
  vim.api.nvim_set_hl(0, "LocalStatusMuted", {
    fg = color("Comment", "#9399b2"), bg = "NONE",
  })
  for name, spec in pairs({
    Normal = { "DiagnosticInfo", "#89b4fa" },
    Insert = { "DiagnosticOk", "#a6e3a1" },
    Visual = { "Statement", "#cba6f7" },
    Replace = { "DiagnosticError", "#f38ba8" },
    Command = { "DiagnosticWarn", "#f9e2af" },
    Terminal = { "DiagnosticHint", "#94e2d5" },
  }) do
    vim.api.nvim_set_hl(0, "LocalStatusMode" .. name, {
      fg = "#11111b", bg = color(spec[1], spec[2]), bold = true,
    })
  end
  for _, severity in ipairs({ "Error", "Warn", "Info", "Hint" }) do
    vim.api.nvim_set_hl(0, "LocalStatus" .. severity, {
      fg = color("Diagnostic" .. severity, normal), bg = "NONE",
    })
  end
end

local function mode_label()
  local mode = vim.api.nvim_get_mode().mode
  local first = mode:sub(1, 1)
  if first == "i" then return "INSERT", "Insert" end
  if first == "R" then return "REPLACE", "Replace" end
  if first == "c" or first == "r" or first == "!" then return "COMMAND", "Command" end
  if first == "t" then return "TERMINAL", "Terminal" end
  if first == "v" then return "VISUAL", "Visual" end
  if first == "V" then return "V-LINE", "Visual" end
  if first == "\22" then return "V-BLOCK", "Visual" end
  if first == "s" or first == "S" or first == "\19" then return "SELECT", "Visual" end
  if mode:sub(1, 2) == "no" then return "OPERATOR", "Normal" end
  return "NORMAL", "Normal"
end

function M.render()
  local win = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then return "" end
  local buf = vim.api.nvim_win_get_buf(win)
  local bo = vim.bo[buf]
  local width = vim.o.laststatus == 3 and vim.o.columns or vim.api.nvim_win_get_width(win)
  local mode, group = mode_label()
  local parts = { "%#LocalStatusMode" .. group .. "# " .. mode .. " %#LocalStatusBase# %<" }

  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    name = "[No Name]"
  elseif bo.buftype == "terminal" then
    name = "Terminal"
  else
    name = vim.fn.fnamemodify(name, width >= options.path_width and ":~:." or ":t")
  end
  parts[#parts + 1] = escape(name)
  if bo.modified then parts[#parts + 1] = " [+]" end
  if bo.readonly or (not bo.modifiable and bo.buftype ~= "terminal") then
    parts[#parts + 1] = " [RO]"
  end
  parts[#parts + 1] = "%="

  if width >= options.details_width then
    local counts = vim.diagnostic.count(buf)
    for _, item in ipairs({ { "Error", "E" }, { "Warn", "W" }, { "Info", "I" }, { "Hint", "H" } }) do
      local count = counts[vim.diagnostic.severity[item[1]:upper()]] or 0
      if count > 0 then
        parts[#parts + 1] = "%#LocalStatus" .. item[1] .. "# " .. item[2] .. ":" .. count
      end
    end
    parts[#parts + 1] = "%#LocalStatusMuted#  " .. escape(bo.filetype ~= "" and bo.filetype or "text")
    if width >= options.path_width then
      local encoding = bo.fileencoding ~= "" and bo.fileencoding or vim.o.encoding
      parts[#parts + 1] = "  " .. escape(encoding) .. " / " .. escape(bo.fileformat)
    end
  end
  parts[#parts + 1] = "%#LocalStatusBase#  %l:%c  %p%% "
  return table.concat(parts)
end

function M.setup(opts)
  options = vim.tbl_extend("force", defaults, opts or {})
  highlights()
  vim.o.laststatus = 3
  vim.o.showmode = false
  vim.o.statusline = "%!v:lua.require'plugins.statusline'.render()"

  local group = vim.api.nvim_create_augroup("LocalStatusline", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  vim.api.nvim_create_autocmd({ "ModeChanged", "DiagnosticChanged", "BufModifiedSet", "BufFilePost" }, {
    group = group,
    callback = function() vim.cmd("redrawstatus") end,
  })
end

return M
