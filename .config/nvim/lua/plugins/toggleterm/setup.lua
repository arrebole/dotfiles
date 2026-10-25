vim.pack.add({
  { src = "https://github.com/akinsho/toggleterm.nvim", version = vim.version.range("2") },
})

vim.o.hidden = true
-- Windows 的默认 /s /c 参数只适用于 cmd.exe；PowerShell 需要自己的参数。
local shell = vim.o.shell:lower()
if vim.fn.has("win32") == 1 and vim.o.shellcmdflag == "/s /c"
  and (shell:find("powershell", 1, true) or shell:find("pwsh", 1, true)) then
  vim.o.shellcmdflag = "-NoLogo -NoProfile -Command"
  vim.o.shellquote = ""
  vim.o.shellxquote = ""
end
require("toggleterm").setup(require("plugins.toggleterm.config"))
