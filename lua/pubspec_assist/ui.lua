local api = vim.api
local M = {
	is_open = false,
	current_buf = nil,
}

local function set_mappings(buf_id, maps)
	for _, map in ipairs(maps) do
		api.nvim_buf_set_keymap(buf_id, map.mode, map.lhs, map.rhs, {
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
			rhs = ':lua require"pubspec_assist".close_current_window()<cr>'
		},
		{
			mode = 'i',
			lhs  = '<Esc>',
			rhs = '<c-o>:lua require"pubspec_assist".close_current_window()<cr>'
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
	if M.current_buf then
		vim.cmd('bw '..M.current_buf)
		M.current_buf = nil
	end
end

local function set_current_buf(buf)
	M.current_buf = buf
end

local function reset_win()
	if M.is_open then
		M.close()
	end
	M.is_open = true
end

--- @param title string
--- @param callback_name string
--- @param cb function
function M.input_window(title, callback_name, cb)
	reset_win()
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
		row = 0,
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

	vim.cmd('autocmd BufWipeout,BufDelete <buffer> execute "bw '..parent_buf..'"')
	set_mappings(buf, vim.list_extend({
		{
			mode = "i",
			lhs = "<CR>",
			rhs = "<c-o>:lua require'pubspec_assist'."..callback_name.."()<CR>"
		}
	}, default_mappings))
	vim.cmd('startinsert!')

	set_current_buf(buf)
	if cb then cb(win, buf) end
end

--- @param content table
--- @param callback_name string
--- @param cb function
function M.list_window(content, callback_name, cb)
	reset_win()
	local buf = api.nvim_create_buf(false, true)
	api.nvim_buf_set_lines(buf, 0, -1, false, content)

	local max_width = get_max_width(content, 50)
	local width = max_width + 2
	local height = math.min(#content, vim.fn.float2nr(vim.o.lines * 0.5) - 3)
	local opts = {
		relative = 'cursor',
		width = width,
		height = height,
		col = 1,
		row = 0,
		style = 'minimal',
		focusable = true
	}
	local win = api.nvim_open_win(buf, true, opts)
	api.nvim_buf_set_option(buf, 'modifiable', false)

	vim.wo[win].cursorline = true
	vim.cmd('set winhighlight=CursorLine:TabLineSel')

	set_mappings(buf, vim.list_extend({
				{ mode = 'n',
					lhs = '<CR>',
					rhs = ':lua require"pubspec_assist".'..callback_name..'()<CR>',
				},
			}, default_mappings)
		)

	set_current_buf(buf)

	if cb then cb(win, buf) end
end

local function pad(line)
	return " " ..line .. " "
end

local function format_packages(packages)
	local strings = {}
	for _,package in ipairs(packages) do
		local str = package.name .. ', version: ' .. package.latest.version
		table.insert(strings, pad(str))
	end
	return strings
end

--- @param cb_name string
function M.input_package(cb_name)
	M.input_window('Package name', cb_name)
end

function M.list_packages(content)
	local next_url = content.next_url
	local packages = format_packages(content.packages)
	M.list_window(vim.list_extend(packages, {next_url}), 'insert_package')
end

return M
