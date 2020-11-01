local M = {}
--- @param ft string
function M.assist_error(ft)
  local cmd = ft  == ''
    and "Dependency couldn't get the correct filetype"
    or 'Dependency assist does not support '..ft
  M.echoerr(cmd)
end

--- @param text string
function M.insert_at_cursor_pos(text)
  vim.cmd('execute "normal! i' .. text .. '\\<Esc>"')
end

--- @param error string
function M.echoerr(error)
  vim.cmd(string.format('echoerr "%s"', error))
end

--- @param buf_id integer
--- @param filename string
function M.is_dependency_file(buf_id, filename)
  local fname = vim.fn.expand('#'..buf_id..':t')
  return fname == filename
end

return M
