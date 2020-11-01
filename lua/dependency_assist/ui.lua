local api = vim.api
local helpers = require'dependency_assist/helpers'

local M = {
  is_open = false,
  current_buf = nil,
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

local function pad(line)
  return " " ..line .. " "
end


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

--- @param width integer
--- @param height integer
local function get_window_config(width, height)
  local win_width = vim.fn.winwidth(0)
  local row = (vim.o.lines - 3 - height) / 2
  local col = (win_width - width) / 2
  local opts = {
    relative = 'win',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    focusable = true
  }
  return opts
end

local function set_current_buf(buf)
  M.current_buf = buf
  M.is_open = true
end

--- @param buf number
--- @param title string
local function highlight_title(buf, title)
  local start_col = 4
  api.nvim_buf_add_highlight(
    buf,
    -1, -- namespace ID (unnecessary)
    'Title', -- Higlight group
    0, -- line number
    start_col, -- start
    start_col + title:len() -- end
  )
end

local function bordered_window(win_opts, callback)
  M.close()
  local parent_buf = api.nvim_create_buf(false, true)
  local max_width = win_opts.width

  local title = pad(win_opts.title)
  local remainder = max_width - string.len(title)
  local padded_title = title .. string.rep("─", remainder - 2)
  local padding = string.rep(" ", max_width - 2)
  local content_width = string.len(padding)
  local bottom_line = string.rep("─", content_width)

  local top = "╭" .. padded_title .. "╮"
  local mid = "│" ..   padding    .. "│"
  local bot = "╰" .. bottom_line  .. "╯"

  local lines = {top}
  for _=1,win_opts.height do
    table.insert(lines, mid)
  end
  table.insert(lines, bot)

  api.nvim_buf_set_lines(parent_buf, 0, -1, false, lines)
  highlight_title(parent_buf, win_opts.title)

  local height = #lines
  local config = get_window_config(max_width, height)
  local win = api.nvim_open_win(parent_buf, false, config)

  config.row = config.row + 1
  config.height = height - 2
  config.col = config.col + 2
  config.width = config.width - 4

  callback(win, parent_buf, config)
end

--- @param title string
--- @param options table
function M.input_window(title, options)
  bordered_window({
      title = title,
      width = 40,
      height = 1,
    },
    function(_, parent_buf, config)
      config.focusable = false
      local buf = api.nvim_create_buf(false, true)
      local win = api.nvim_open_win(buf, true, config)

      -- TODO once native lua callbacks are allowed in mappings
      -- remove this global function
      function _G.__dep_assist_input_cb()
        options.on_select(options.buf_id)
      end

      set_mappings(buf, vim.list_extend({
            {
              mode = "i",
              lhs = "<CR>",
              rhs = "<c-o>:lua __dep_assist_input_cb()<CR>"
            }
        }, default_mappings))
      vim.cmd('startinsert!')
      cleanup_autocommands(parent_buf)

      set_current_buf(buf)
      if options.on_open then options.on_open(win, buf) end
    end)
end

--- @param title string
--- @param content table
--- @param options table
function M.list_window(title, content, options)
  local max_width = get_max_width(content, 50)
  local height = math.min(#content, vim.fn.float2nr(vim.o.lines * 0.5) - 3)
  bordered_window({
      title = title,
      width = max_width,
      height = height,
    },
    function(_, parent_buf, config)
      local formatted = {}
      for _, item in ipairs(content) do
        table.insert(formatted, pad(item))
      end

      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, 0, -1, false, formatted)

      local win = api.nvim_open_win(buf, true, config)
      api.nvim_buf_set_option(buf, 'modifiable', false)

      vim.wo[win].cursorline = true
      api.nvim_win_set_option(win, 'winhl', 'CursorLine:TabLineSel')
      cleanup_autocommands(parent_buf)

      -- TODO once native lua callbacks are allowed in mappings
      -- remove this global function
      function _G.__dep_assist_list_cb()
        options.on_select(options.buf_id)
      end

      set_mappings(buf, vim.list_extend({
            { mode = 'n',
              lhs = '<CR>',
              rhs = ':lua __dep_assist_list_cb()<CR>',
            },
          }, default_mappings)
        )
      set_current_buf(buf)

      if options.on_open then options.on_open(win, buf) end
    end)
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
