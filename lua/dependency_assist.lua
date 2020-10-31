local pubspec_api = require 'dependency_assist/pubspec_api'
local formatters = require 'dependency_assist/formatters'
local ui = require 'dependency_assist/ui'

local M = {}
local supported_filetypes = {
	dart = {filename = 'pubspec.yaml'}
}

--- @param text string
local function insert_at_cursor_pos(text)
	vim.cmd('execute "normal! i' .. text .. '\\<Esc>"')
end

local function insert_package()
	local package = vim.fn.getline('.')
	ui.close()
	insert_at_cursor_pos(package)
end

local function get_package()
	local package = vim.fn.trim(vim.fn.getline('.'))
	if package then
		pubspec_api.get_package(package, function (data)
			local versions = formatters.dart.format_package_details(data)
			ui.list_window(versions, insert_package)
		end)
	end
end

local function search_package()
	local input = ui.get_current_input()
	if input:len() > 0 then
		pubspec_api.search_package(input, function (data)
			local result = {}
			if data then
				for _, pkg in pairs(data.packages) do
					table.insert(result, pkg.package)
				end
				ui.list_window(result, get_package)
			end
		end)
	end
end

-- local function list_packages(data)
-- 	local packages,next_url = formatters.dart.format_packages(data)
-- 	M.list_window(vim.list_extend(packages, {next_url}), insert_package)
-- end

--- 1. start package search by opening an input buffer, which registers
--- a callback once the a selection is made triggering a searck
function M.start_package_search()
	ui.input_window(' Package name ', search_package)
end

--- @param preferences table
function M.setup_ft(preferences)
	vim.cmd('command! -buffer SearchPackage lua require"dependency_assist".start_package_search()')

	local key = (preferences and preferences.key or nil)
	if not key then return end

	local buf_id = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_keymap(buf_id, 'n', key, ':SearchPackage<CR>',
		{noremap = true, silent = true }
	)
end

function M.setup(preferences)
	local fts = {}
	for _,ft in pairs(supported_filetypes) do
		table.insert(fts, ft.filename)
	end
	local all_fts = table.concat(fts, ',')

	function _G.__dep_assist_ft_setup()
		M.setup_ft(preferences)
	end

	vim.cmd('autocmd! BufEnter '..all_fts..' lua _G.__dep_assist_ft_setup()')
end

M.close_current_window = ui.close

return M
