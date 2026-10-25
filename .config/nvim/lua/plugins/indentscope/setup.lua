-- 使用当前目录中的本地源码，同时让 Neovim 能找到随附的帮助文档。
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
vim.opt.runtimepath:prepend(plugin_dir)

-- 浮动工具窗口不显示代码缩进范围。
local group = vim.api.nvim_create_augroup("LocalIndentscope", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "yazi", "fzf", "lazygit", "cmdpal" },
  callback = function(event)
    vim.b[event.buf].miniindentscope_disable = true
  end,
})

-- 兼容重新加载配置时已有的工具窗口。
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.tbl_contains({ "yazi", "fzf", "lazygit", "cmdpal" }, vim.bo[buf].filetype) then
    vim.b[buf].miniindentscope_disable = true
  end
end

require("plugins.indentscope.indentscope").setup(require("plugins.indentscope.config"))
