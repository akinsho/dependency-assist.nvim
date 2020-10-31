local pubspec_api = require 'dependency_assist/pubspec_api'
local formatters = require 'dependency_assist/formatters'
local ui = require 'dependency_assist/ui'

local M = {}
local supported_filetypes = {
	dart = {filename = 'pubspec.yaml'}
}

--- @param str string
local function insert_at_cursor_pos(str)
	vim.cmd('execute "normal! i' .. str .. '\\<Esc>"')
end

function M.start_package_search()
	ui.input_window(' Package name ', 'search_package')
end

function M.get_package()
	local package = vim.fn.trim(vim.fn.getline('.'))
	if package then
		pubspec_api.get_package(package, function (data)
			local versions = formatters.dart.format_package_details(data)
			ui.list_window(versions, 'insert_package')
		end)
	end
end

function M.list_packages(data)
	local packages,next_url = formatters.dart.format_packages(data)
	M.list_window(vim.list_extend(packages, {next_url}), 'insert_package')
end

function M.search_package()
	local input = ui.get_current_input()
	if input:len() > 0 then
		pubspec_api.search_package(input, function (data)
			local result = {}
			if data then
				for _, pkg in pairs(data.packages) do
					table.insert(result, pkg.package)
				end
				ui.list_window(result, 'get_package')
			end
		end)
	end
end

function M.insert_package()
	local package = vim.fn.getline('.')
	ui.close()
	insert_at_cursor_pos(package)
end

function M.setup(preferences)
	local trigger_key = (preferences and preferences.key or nil)
	vim.cmd('command SearchPackage lua require"dependency_assist".start_package_search()')
	if trigger_key then
		for _,ft in ipairs(supported_filetypes) do
			vim.cmd('autocmd! BufEnter **/'..ft.filename..' :nnoremap <buffer><silent> '..trigger_key..' :SearchPackage<CR>' )
		end
	end
end

M.close_current_window = ui.close

return M
