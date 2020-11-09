local M = {}

function M.create_cmd(cmd_name, cmd_type, func_name)
  vim.cmd(
    "command! " ..
      (cmd_type and "-" .. cmd_type or "") ..
        " " ..
          cmd_name .. ' lua require"dependency_assist".' .. func_name .. "()"
  )
end

--- @param ft string
function M.assist_error(ft)
  local cmd =
    ft == "" and "Dependency couldn't get the correct filetype" or
    "Dependency assist does not support " .. ft
  M.echoerr(cmd)
end

--- @param msg string
--- @param hl string
function M.echomsg(msg, hl)
  hl = hl or "Title"
  vim.cmd("echohl " .. hl)
  vim.cmd(string.format('echomsg "%s"', msg))
  vim.cmd("echohl clear")
end

--- @param lnum string
--- @param text string
function M.insert_beneath(lnum, text)
  -- TODO see appendbufline()
  vim.fn.append(lnum, text)
end

--- @param error string
function M.echoerr(error)
  vim.cmd(string.format('echoerr "%s"', error))
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

--- escape any special non alphanumeric characters in a string
--- @param text string
function M.escape_pattern(text)
  return text:gsub("([^%w])", "%%%1")
end

return M
