local M = {}
local terminal = require("plugins.float-terminal")
local files = require("plugins.files")
local options, scan

function M.close()
  if scan then
    local pending = scan
    scan = nil
    if pending.process then pending.process:kill(15) end
  end
  terminal.close("fzf")
end

function M.open(directory)
  if terminal.focus("fzf") then return end
  if scan then vim.notify("正在扫描文件，可用 :FzfClose 取消。"); return end
  for _, executable in ipairs({ options.executable, options.rg }) do
    if vim.fn.executable(executable) ~= 1 then
      vim.notify("找不到 " .. executable .. "，请安装并加入 PATH。", vim.log.levels.WARN); return
    end
  end
  local previous = files.editor()
  local cwd = vim.fs.abspath(directory or files.project(previous))
  if vim.fn.isdirectory(cwd) ~= 1 then vim.notify("目录不存在：" .. cwd, vim.log.levels.WARN); return end
  local args = { options.rg, "--files", "--null", "-g", "!.git" }
  if options.hidden then args[#args + 1] = "--hidden" end
  local pending = {}
  scan = pending
  pending.process = vim.system(args, { cwd = cwd }, function(result)
    vim.schedule(function()
      if scan ~= pending then return end
      scan = nil
      if result.code > 1 then vim.notify(result.stderr, vim.log.levels.ERROR); return end
      if result.stdout == "" then vim.notify("当前目录没有可查询的文件。"); return end
      local input, output = vim.fn.tempname(), vim.fn.tempname()
      files.write(input, result.stdout)
      local env = {
        NVIM_FZF_EXE = vim.fn.exepath(options.executable), NVIM_FZF_INPUT = input, NVIM_FZF_OUTPUT = output,
        FZF_DEFAULT_OPTS = "", FZF_DEFAULT_OPTS_FILE = "", FZF_DEFAULT_COMMAND = "",
      }
      -- 命令文本固定；路径经环境变量传入并引用，不将文件名拼进 shell 代码。
      local flags = " --read0 --print0 --multi --layout=reverse --no-height --bind=esc:abort,ctrl-c:abort"
      local command
      if vim.fn.has("win32") == 1 then
        command = { vim.env.COMSPEC or "cmd.exe", "/d", "/v:off", "/s", "/c",
          '""%NVIM_FZF_EXE%"' .. flags .. ' < "%NVIM_FZF_INPUT%" > "%NVIM_FZF_OUTPUT%""' }
      else
        command = { "sh", "-c", 'exec "$NVIM_FZF_EXE"' .. flags .. ' < "$NVIM_FZF_INPUT" > "$NVIM_FZF_OUTPUT"' }
      end
      terminal.open("fzf", command, vim.tbl_extend("force", options, {
        title = "fzf · Files", previous = previous, cwd = cwd, env = env,
        on_exit = function(code, cancelled, lines)
          local selected = {}
          if not cancelled and code == 0 and vim.fn.filereadable(output) == 1 then
            for _, path in ipairs(vim.split(files.read(output), "\0", { plain = true, trimempty = true })) do
              selected[#selected + 1] = vim.fs.joinpath(cwd, path)
            end
          end
          vim.fn.delete(input)
          vim.fn.delete(output)
          if not cancelled and code ~= 0 and code ~= 1 and code ~= 130 then
            vim.notify("fzf 退出码 " .. code .. "\n" .. table.concat(lines, "\n"), vim.log.levels.ERROR)
          end
          files.open(selected, previous)
        end,
      }))
    end)
  end)
end

function M.setup(opts)
  options = vim.tbl_extend("force", { executable = "fzf", rg = "rg", hidden = true }, opts or {})
  vim.api.nvim_create_user_command("FzfFiles", function(args)
    M.open(args.args ~= "" and args.args or nil)
  end, { nargs = "?", complete = "dir", desc = "浮动 fzf：项目或指定目录的文件" })
  vim.api.nvim_create_user_command("FzfFilesCwd", function() M.open(vim.fn.getcwd()) end,
    { desc = "浮动 fzf：工作目录的文件" })
  vim.api.nvim_create_user_command("FzfClose", M.close, { desc = "关闭 fzf 或取消扫描" })
end

return M
