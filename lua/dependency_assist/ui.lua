local api = vim.api
local helpers = require'dependency_assist/utils/helpers'

local namespace = vim.api.nvim_create_namespace('dependency_assist')

local MAX_WIDTH = 50

local M = {}

local state = {
  is_open = false,
  current = nil,
  enclosing_window = nil,
}

--- @param parent_buf number
local function cleanup_autocommands(parent_buf)
  helpers.create_augroups({
      dependency_assist_cleanup = {
        {
          "BufWipeout,BufDelete",
          "<buffer>",
          string.format([[execute "bw %d | stopinsert"]], parent_buf),
        };
        {
          "WinLeave",
          "<buffer>",
          "nested",
          [[lua require"dependency_assist".close_current_window()]],
        };
    }
  })
end

local function set_mappings(buf_id, maps)
  local close_fn = [[:lua require"dependency_assist".close_current_window()<CR>]]
  local default_mappings = {
    { mode = 'n', lhs = '<Esc>', rhs = close_fn },
    { mode = 'i', lhs = '<Esc>', rhs = '<c-o>'..close_fn }
  }
  maps = vim.list_extend(maps, default_mappings)
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

local function get_current_input()
  local buf = api.nvim_get_current_buf()
  local input = api.nvim_buf_get_lines(buf, 0, -1, false)
  return input
end

--- @param line string
local function pad(line)
  return " " ..line .. " "
end

--- @param content table
local function format_content(content)
  local formatted = {}
  for _, item in ipairs(content) do
    table.insert(formatted, pad(item))
  end
  return formatted
end

--- @param lines table
--- @param max_width number
local function get_max_width(lines, max_width)
  for _, line in pairs(lines) do
    if string.len(line) > max_width then
      max_width = string.len(line)
    end
  end
  return max_width
end

function M.close()
  if state and state.is_open then
    vim.cmd('bw '..state.current.buf)
    state.current = nil
    state.is_open = false
  end
end

--- @param width integer
--- @param height integer
local function get_window_config(width, height)
  local win_width = api.nvim_win_get_width(state.enclosing_window)
  local row = math.floor((vim.o.lines * 0.5 - vim.o.cmdheight -1) / 2)
  local col = math.floor((win_width - width) / 2)
  return {
    relative = 'win',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    focusable = false
  }
end

local function register_current(buf)
  state.current = buf
  state.is_open = true
end

--- @param buf number
--- @param title string
local function highlight_title(buf, title)
  if not title then return end
  local start_col = 4
  api.nvim_buf_add_highlight(
    buf,
    -1, -- Namespace ID (unnecessary)
    'Title', -- Highlight group
    0, -- line number
    start_col, -- start
    start_col + title:len() -- end
  )
end

--- @param title string
--- @param width number
--- @param fallback string
--- @return string
local function window_title(title, width, fallback)
  if not title then return fallback end
  title = pad(title)
  local remainder = width - string.len(title)
  title = title .. string.rep("─", remainder - 2)
  return title
end

local function bordered_window(win_opts, callback)
  M.close()
  local buf = api.nvim_create_buf(false, true)
  local padding = string.rep(" ", win_opts.width - 2)
  local content_width = string.len(padding)
  local bottom_line = string.rep("─", content_width)

  local title = window_title(
    win_opts.title,
    win_opts.width,
    bottom_line
  )

  local top = "╭" ..    title     .. "╮"
  local mid = "│" ..   padding    .. "│"
  local bot = "╰" .. bottom_line  .. "╯"

  local lines = {top}
  for _ = 1, win_opts.height do
    table.insert(lines, mid)
  end
  table.insert(lines, bot)

  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  highlight_title(buf, win_opts.title)

  local height = #lines
  local config = get_window_config(win_opts.width, height)
  local win = api.nvim_open_win(buf, false, config)

  config.row = config.row + 1
  config.height = height - 2
  config.col = config.col + 2
  config.width = config.width - 4
  config.focusable = true

  callback(win, buf, config)
end

--- @param title string
--- @param options table
function M.input_window(title, options)
  local border_opts = {title = title, width = MAX_WIDTH, height = 1}
  bordered_window(border_opts, function(parent_win, parent_buf, config)
    local buf = api.nvim_create_buf(false, true)
    local win = api.nvim_open_win(buf, true, config)

    function _G.__dep_assist_input_cb()
      options.on_select(options.buf_id, get_current_input())
    end

    set_mappings(buf, {{
      mode = "i",
      lhs = "<CR>",
      rhs = "<c-o>:lua __dep_assist_input_cb()<CR>"
    }})
    vim.cmd('startinsert!')
    cleanup_autocommands(parent_buf)

    register_current({buf = buf, win = win, type = 'input', parent = parent_win})
    if options.on_open then options.on_open(win, buf) end
  end)
end

--- @param content table<string>
--- @return table<string>, bool
local function validate_content(content)
  if #content == 0 then
    return {'No results'}, false
  else
    return content, true
  end
end

function M.loading_window()
  local opts = {height = 1, width = MAX_WIDTH}
  bordered_window(opts, function(parent_win, parent_buf, config)
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, {'loading...'})
    local win = api.nvim_open_win(buf, true, config)
    vim.bo[buf].modifiable = false
    cleanup_autocommands(parent_buf)
    set_mappings(buf, {{
          mode = 'n',
          lhs = '<CR>',
          rhs = ':lua require"dependency_assist".close_current_window()<CR>',
      }})
    register_current({buf = buf, win = win, type = 'list', parent = parent_win})
    vim.cmd('redraw!')
  end)
end

--- @param title string
--- @param content table
--- @param options table
function M.list_window(title, content, options)
  local width = get_max_width(content, MAX_WIDTH)
  local max_height = vim.fn.float2nr(vim.o.lines * 0.5) - vim.o.cmdheight - 1
  local validated, is_valid = validate_content(content)
  content = validated

  local height = math.min(#content, max_height)
  title = title ..' ('..#content..')'
  local border_opts = {title = title, width = width, height = height}
  local formatted = format_content(content)

  bordered_window(border_opts, function(parent_win, parent_buf, config)
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, formatted)
    local win = api.nvim_open_win(buf, true, config)

    local modifiable = options.modifiable ~= nil and options.modifiable or false
    vim.bo[buf].modifiable = modifiable
    vim.wo[win].cursorline = true
    vim.wo[win].winhighlight = 'CursorLine:TabLineSel'
    cleanup_autocommands(parent_buf)

    function _G.__dep_assist_list_cb()
      options.on_select(options.buf_id, get_current_input())
    end

    local cmd = is_valid
      and [[__dep_assist_list_cb()]]
      or [[require"dependency_assist".close_current_window()<CR>]]

    set_mappings(buf, {{
      mode = 'n',
      lhs = '<CR>',
      rhs = ':lua '..cmd..'<CR>',
    }})
    register_current({buf = buf, win = win, type = 'list', parent = parent_win})

    if options.on_open then options.on_open(win, buf) end
  end)
end

function M.set_parent_window(id)
  M.enclosing_window = id
end

--- @param buf_id number
function M.clear_virtual_text(buf_id)
  api.nvim_buf_clear_namespace(buf_id, namespace, 0, -1)
end

--- @param buf_id number
--- @param lnum number
--- @param text string
--- @param hl string
function M.set_virtual_text(buf_id, lnum, text, hl)
  hl = hl or 'Comment'
  vim.api.nvim_buf_set_virtual_text(buf_id, namespace, lnum, {{text, hl}}, {})
end

return M
