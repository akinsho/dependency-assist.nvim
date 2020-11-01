local api = vim.api
local M = {
  is_open = false,
  current_buf = nil,
}

function M.get_current_input()
  local input = vim.fn.trim(vim.fn.getline('.'))
  M.close()
  return input
end

local function set_mappings(buf_id, maps)
  for _, map in ipairs(maps) do
    api.nvim_buf_set_keymap(
      buf_id,
      map.mode,
      map.lhs,
      map.rhs,
      {
        nowait = true,
        silent = true,
        noremap = true,
      })
  end
end

local default_mappings = {
    {
      mode = 'n',
      lhs  = '<Esc>',
      rhs = ':lua require"dependency_assist".close_current_window()<cr>'
    },
    {
      mode = 'i',
      lhs  = '<Esc>',
      rhs = '<c-o>:lua require"dependency_assist".close_current_window()<cr>'
    }
  }

--- @param lines table
--- @param max_width number
local function get_max_width(lines, max_width)
  for _, line in pairs(lines) do
    if string.len(line) > max_width then max_width = string.len(line) end
  end
  return max_width
end

function M.close()
  if M.current_buf and M.is_open then
    vim.cmd('bw '..M.current_buf)
    M.current_buf = nil
    M.is_open = false
  end
end

local function set_current_buf(buf)
  M.current_buf = buf
  M.is_open = true
end

--- @param title string
--- @param on_select function
--- @param on_open function
function M.input_window(title, on_select, on_open)
  M.close()
  local parent_buf = api.nvim_create_buf(false, true)
  local max_width = 30

  local remainder = max_width - string.len(title)
  local padded_title = title .. string.rep("─", remainder - 2)
  local padding = string.rep(" ", max_width - 2)
  local content_width = string.len(padding)
  local bottom_line = string.rep("─", content_width)

  local top = "╭" .. padded_title .. "╮"
  local mid = "│" ..    padding   .. "│"
  local bot = "╰" .. bottom_line  .. "╯"
  local lines = { top, mid, bot }

  api.nvim_buf_set_lines(parent_buf, 0, -1, false, lines)

  local height = #lines
  local opts = {
    relative = 'cursor',
    width = max_width,
    height = height,
    col = 1,
    row = 1,
    style = 'minimal',
    focusable = true
  }
  api.nvim_open_win(parent_buf, false, opts)

  opts.height = 1
  opts.width = max_width - 2
  opts.col = opts.col + 1
  opts.row = opts.row + 1

  local buf = api.nvim_create_buf(false, true)
  local win = api.nvim_open_win(buf, true, opts)

  vim.cmd('autocmd BufWipeout,BufDelete <buffer> execute "bw '..parent_buf..'" | stopinsert')

  -- TODO once native lua callbacks are allowed in mappings
  -- remove this global function
  function _G.__dep_assist_input_cb()
    on_select()
  end

  set_mappings(buf, vim.list_extend({
    {
      mode = "i",
      lhs = "<CR>",
      rhs = "<c-o>:lua __dep_assist_input_cb()<CR>"
    }
  }, default_mappings))
  vim.cmd('startinsert!')

  set_current_buf(buf)
  if on_open then on_open(win, buf) end
end

local function pad(line)
  return " " ..line .. " "
end

--- @param content table
--- @param on_select function
--- @param on_open function
function M.list_window(content, on_select, on_open)
  M.close()

  local formatted = {}
  for _, item in ipairs(content) do
    table.insert(formatted, pad(item))
  end

  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, formatted)

  local max_width = get_max_width(content, 50)
  local width = max_width + 2
  local height = math.min(#content, vim.fn.float2nr(vim.o.lines * 0.5) - 3)
  local opts = {
    relative = 'cursor',
    width = width,
    height = height,
    col = 1,
    row = 1,
    style = 'minimal',
    focusable = true
  }
  local win = api.nvim_open_win(buf, true, opts)
  api.nvim_buf_set_option(buf, 'modifiable', false)

  vim.wo[win].cursorline = true
  vim.cmd('set winhighlight=CursorLine:TabLineSel')

  -- TODO once native lua callbacks are allowed in mappings
  -- remove this global function
  function _G.__dep_assist_list_cb()
    on_select()
  end

  set_mappings(buf, vim.list_extend({
        { mode = 'n',
          lhs = '<CR>',
          rhs = ':lua __dep_assist_list_cb()<CR>',
        },
      }, default_mappings)
    )

  set_current_buf(buf)

  if on_open then on_open(win, buf) end
end

--- @param buf_id number
--- @param lnum number
--- @param text string
--- @param hl string
function M.set_virtual_text(buf_id, lnum, text, hl)
  hl = hl or 'Comment'
  local ns = vim.api.nvim_create_namespace('dependency_assist')
  vim.api.nvim_buf_set_virtual_text(buf_id, ns, lnum, {{text, hl}}, {})
end

return M
