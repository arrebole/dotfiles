return {
  direction = "float",
  open_mapping = "<F7>",
  insert_mappings = false,
  terminal_mappings = true,
  start_in_insert = true,
  persist_mode = true,
  close_on_exit = true,
  shade_terminals = false,
  float_opts = {
    border = "rounded",
    width = function() return math.max(1, math.floor(vim.o.columns * 0.9)) end,
    height = function() return math.max(1, math.floor((vim.o.lines - vim.o.cmdheight - 2) * 0.85)) end,
    winblend = 0,
    title_pos = "center",
  },
  on_open = function(term)
    vim.b[term.bufnr].miniindentscope_disable = true
    -- 只绑定 ToggleTerm buffer，避免影响 Yazi、fzf 和 LazyGit。
    vim.keymap.set({ "n", "t" }, "<C-q>", function() term:close() end,
      { buffer = term.bufnr, desc = "隐藏终端（保留进程）" })
    vim.keymap.set("n", "q", function() term:close() end,
      { buffer = term.bufnr, desc = "隐藏终端（保留进程）" })
  end,
}
