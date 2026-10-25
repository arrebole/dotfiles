local M = {}
local terminal = require("plugins.float-terminal")
local files = require("plugins.files")
local options

function M.open(path)
  if terminal.focus("yazi") then return end
  if vim.fn.executable(options.executable) ~= 1 then
    vim.notify("找不到 yazi，请安装并加入 PATH。", vim.log.levels.WARN); return
  end
  local previous = files.editor()
  path = vim.fs.abspath(path or files.current(previous))
  local cwd = files.directory(path)
  if vim.fn.isdirectory(cwd) ~= 1 then
    vim.notify("目录不存在：" .. cwd, vim.log.levels.WARN); return
  end
  vim.api.nvim_exec_autocmds("User", { pattern = "LocalDirectoryOpened", data = { path = cwd } })
  local output = vim.fn.tempname()
  terminal.open("yazi", { options.executable, "--chooser-file", output, "--", path },
    vim.tbl_extend("force", options, {
      title = "Yazi", previous = previous, cwd = cwd,
      on_exit = function(code, cancelled, lines)
        local selected = vim.fn.filereadable(output) == 1 and vim.fn.readfile(output) or {}
        vim.fn.delete(output)
        vim.cmd("checktime")
        if not cancelled and code == 0 then files.open(selected, previous)
        elseif not cancelled and code ~= 130 then
          vim.notify("Yazi 退出码 " .. code .. "\n" .. table.concat(lines, "\n"), vim.log.levels.ERROR)
        end
      end,
    }))
end

function M.setup(opts)
  options = vim.tbl_extend("force", { executable = "yazi" }, opts or {})
  vim.api.nvim_create_user_command("Yazi", function(args)
    M.open(args.args ~= "" and args.args or nil)
  end, { nargs = "?", complete = "file", desc = "浮动 Yazi：当前文件或指定路径" })
  vim.api.nvim_create_user_command("YaziCwd", function() M.open(vim.fn.getcwd()) end,
    { desc = "浮动 Yazi：工作目录" })
  vim.api.nvim_create_user_command("YaziClose", function() terminal.close("yazi") end,
    { desc = "关闭 Yazi 浮窗" })

  -- 目录入口交给 Yazi：支持 nvim . 和 :edit <目录>。
  vim.g.loaded_netrwPlugin = 1
  local group = vim.api.nvim_create_augroup("LocalYaziDirectories", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group, callback = function(event)
      local path = vim.api.nvim_buf_get_name(event.buf)
      if vim.fn.isdirectory(path) ~= 1 then return end
      local win = vim.api.nvim_get_current_win()
      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= event.buf then return end
        local empty = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_win_set_buf(win, empty)
        if vim.api.nvim_buf_is_valid(event.buf) then vim.api.nvim_buf_delete(event.buf, { force = false }) end
        M.open(path)
      end)
    end,
  })
end

return M
