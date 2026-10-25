local M = {}
local history_file

local function directory(path)
  if type(path) ~= "string" or vim.fn.isdirectory(path) ~= 1 then return end
  return vim.fs.normalize(vim.uv.fs_realpath(path) or vim.fs.abspath(path))
end

local function unique(paths)
  local result, seen = {}, {}
  for _, path in ipairs(paths) do
    path = directory(path)
    if path then
      local key = vim.fn.has("win32") == 1 and path:lower() or path
      if not seen[key] then
        result[#result + 1], seen[key] = path, true
        if #result == 100 then break end
      end
    end
  end
  return result
end

function M.project(path)
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  return dir and (vim.fs.root(dir, ".git") or dir)
end

function M.setup(path)
  history_file = path or (vim.fn.stdpath("state") .. "/recent-directories.json")
end

function M.list()
  if vim.fn.filereadable(history_file) == 1 then
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(history_file), "\n"))
    if ok and type(data) == "table" and vim.islist(data) then return unique(data) end
    return {}
  end
  -- 首次启用时，从已有文件记录归并出项目根目录/普通目录。
  local paths = {}
  for _, file in ipairs(vim.v.oldfiles) do
    if vim.fn.filereadable(file) == 1 then paths[#paths + 1] = M.project(file) end
  end
  return unique(paths)
end

function M.remember(path)
  path = directory(path)
  if not path then return end
  local paths = { path }
  vim.list_extend(paths, M.list())
  paths = unique(paths)
  vim.fn.mkdir(vim.fs.dirname(history_file), "p")
  local pending = history_file .. "." .. vim.fn.getpid() .. ".tmp"
  local ok, err = pcall(function()
    vim.fn.writefile({ vim.json.encode(paths) }, pending)
    assert(vim.uv.fs_rename(pending, history_file))
  end)
  if not ok then
    vim.fn.delete(pending)
    vim.notify("无法保存最近目录：" .. tostring(err), vim.log.levels.WARN)
  end
end

return M
