local api = vim.api
local M = {
  is_open = false,
  current_buf = nil,
}

--- @param parent_buf number
local function cleanup_autocommands(parent_buf)

  vim.cmd('autocmd BufWipeout,BufDelete <buffer> execute "bw '..parent_buf..'" | stopinsert')
  -- vim.cmd'autocmd! WinLeave <buffer> lua require"dependency_assist".close_current_window()'
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
--- @param center integer
local function get_window_config(width, height, center)
  local col = center and (vim.o.columns - width) / 2 or 1
  local row = center and (vim.o.lines * 0.2) or 1
  local opts = {
    relative = center and 'editor' or 'cursor',
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

local function bordered_window(win_opts, options, callback)
  M.close()
  local parent_buf = api.nvim_create_buf(false, true)
  local max_width = win_opts.width
  M.parent_buf = parent_buf

  local remainder = max_width - string.len(win_opts.title)
  local padded_title = win_opts.title .. string.rep("─", remainder - 2)
  local padding = string.rep(" ", max_width - 2)
  local content_width = string.len(padding)
  local bottom_line = string.rep("─", content_width)

  local top = "╭" .. padded_title .. "╮"
  local mid = "│" ..   padding    .. "│"
  local bot = "╰" .. bottom_line  .. "╯"
  local lines = { top, mid, bot }

  api.nvim_buf_set_lines(parent_buf, 0, -1, false, lines)

  local height = #lines
  local config = get_window_config(max_width, height, options.center)
  local win = api.nvim_open_win(parent_buf, false, config)
  callback(win, parent_buf, config)
end

--- @param title string
--- @param options table
function M.input_window(title, options)
  bordered_window({ title = title, width = 40},
    options,
    function(_, parent_buf, config)
      config.height = 1
      config.width = config.width - 2
      config.col = config.col + 1
      config.row = config.row + 1
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

--- @param content table
--- @param options table
function M.list_window(content, options)
  local max_width = get_max_width(content, 50)
  bordered_window({title = 'Search query...', width = max_width},
    options,
    function(parent_win, parent_buf, config)
      local formatted = {}
      for _, item in ipairs(content) do
        table.insert(formatted, pad(item))
      end

      local buf = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(buf, 0, -1, false, formatted)

      local width = max_width + 2
      local height = math.min(#content, vim.fn.float2nr(vim.o.lines * 0.5) - 3)

      local opts = config
      local parent_opts = config
      if M.parent_buf then
        parent_opts.row = config.row
        parent_opts.width = width
        parent_opts.height =  config.height + height
        api.nvim_win_set_config(parent_win, parent_opts)
      end
      -- TODO this should be able to be set to config.height but that value
      -- is unusually large
      opts.row = config.row + 3
      opts.width = width
      opts.height = height

      local win = api.nvim_open_win(buf, true, opts)
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
