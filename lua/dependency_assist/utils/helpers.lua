local M = {}
local api = vim.api
local fmt = string.format

function M.create_cmd(cmd_name, cmd_type, func_name)
  vim.cmd(
    "command! " ..
      (cmd_type and "-" .. cmd_type or "") ..
        " " .. cmd_name .. ' lua require"dependency_assist".' .. func_name .. "()"
  )
end

--- @param ft string
function M.assistant_error(ft)
  local cmd =
    not ft or ft == "" and "Dependency assist couldn't get the correct filetype" or
    "Dependency assist does not support " .. ft
  M.echoerr(cmd)
end

--- @param msg string
--- @param hl string
function M.echomsg(msg, hl)
  hl = hl or "Title"
  vim.api.nvim_echo({{msg, hl}}, true, {})
end

--- @param msg string
function M.echoerr(msg)
  if type(msg) == "string" then
    msg = {{msg, "ErrorMsg"}}
  elseif type(msg) == "table" and type(msg[1]) == "table" then
    assert(type(msg[1]) == "string", fmt('%s should be a string', vim.inspect(msg[1])))
    assert(type(msg[2]) == "string", fmt('%s should be a string', vim.inspect(msg[2])))
  else
    msg = {{fmt("Invalid message passed in %s", msg), "ErrorMsg"}}
  end
  vim.api.nvim_echo(msg, true, {})
end

--- @param lnum string
--- @param text string[]
--- @param bufnum integer|nil
function M.insert_beneath(lnum, text, bufnum)
  bufnum = bufnum or 0
  local formatted = {}
  if type(text) == "table" then
    for _, line in ipairs(text) do
      local test_line = lnum >= 0 and lnum - 1 or 0
      local indent_count = vim.fn.indent(test_line)
      local indent = indent_count > 0 and string.rep(" ", indent_count)
      table.insert(formatted, indent .. vim.trim(line))
    end
  end
  api.nvim_buf_set_lines(bufnum, lnum, lnum, false, formatted)
end

--- @param buf_id integer
--- @param filename string
function M.is_dependency_file(buf_id, filename)
  local fname = vim.fn.expand("#" .. buf_id .. ":t")
  return fname == filename
end

local path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"

-- Assumes filepath is a file.
--- @param filepath string
local function dirname(filepath)
  local is_changed = false
  local result =
    filepath:gsub(
    path_sep .. "([^" .. path_sep .. "]+)$",
    function()
      is_changed = true
      return ""
    end
  )
  return result, is_changed
end

function M.path_join(...)
  return table.concat(vim.tbl_flatten {...}, path_sep)
end

--- @param buf_id number
--- @param is_root_path function
function M.find_dependency_file(buf_id, is_root_path)
  -- Ascend the buffer's path until we find the root directory.
  -- is_root_path is a function which returns bool
  local bufname = vim.api.nvim_buf_get_name(buf_id)
  if vim.fn.filereadable(bufname) == 0 then
    return nil
  end
  local dir = bufname
  -- Just in case our algorithm is buggy, don't infinite loop.
  for _ = 1, 100 do
    local did_change
    dir, did_change = dirname(dir)
    if is_root_path(dir, bufname) then
      return dir, bufname
    end
    -- If we can't ascend further, then stop looking.
    if not did_change then
      return nil
    end
  end
end

--- @param definitions table
function M.create_augroups(definitions)
  for group_name, definition in pairs(definitions) do
    vim.cmd("augroup " .. group_name)
    vim.cmd("autocmd!")
    for _, def in ipairs(definition) do
      local command = table.concat(vim.tbl_flatten {"autocmd", def}, " ")
      vim.cmd(command)
    end
    vim.cmd("augroup END")
  end
end

function M.any(comparator, ...)
  local match = false
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    match = comparator(value)
    if match then
      break
    end
  end
  return match
end

function M.is_empty(item)
  return not item or item == ""
end

--- escape any special non alphanumeric characters in a string
--- @param text string
function M.escape_pattern(text)
  if not text then
    return text
  end
  return text:gsub("([^%w])", "%%%1")
end

---@param buf_id number
---@param dependency_file string
function M.find(buf_id, dependency_file)
  local dir =
    M.find_dependency_file(
    buf_id,
    function(dir)
      return vim.fn.filereadable(M.path_join(dir, dependency_file)) == 1
    end
  )
  return M.path_join(dir, dependency_file)
end

---Replace the contents of the specified line
---@param replacement string
---@param lnum number
---@param buf_num number|nil
function M.replace_line(replacement, lnum, buf_num)
  buf_num = buf_num or 0
  api.nvim_buf_set_lines(0, lnum - 1, lnum, false, {replacement})
end

return M
