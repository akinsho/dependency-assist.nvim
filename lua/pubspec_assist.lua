local pubspec_api = require 'pubspec_assist/api'
local ui = require 'pubspec_assist/ui'

local M = {}

local function get_current_input()
	local input = vim.fn.trim(vim.fn.getline('.'))
	ui.close()
	return input
end

function M.start_package_search()
	ui.input_package('search_package')
end

local function format_package_details(data)
	local result = {}
	for _,pkg in ipairs(data.versions) do
		table.insert(result, pkg.pubspec.name ..": " .. pkg.version)
	end
	return result
end

function M.get_package()
	local package = vim.fn.trim(vim.fn.getline('.'))
	if package then
		pubspec_api.get_package(package, function (data)
			local versions = format_package_details(data)
			ui.list_window(versions, 'insert_package')
		end)
	end
end

function M.search_package()
	local input = get_current_input()
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
	print(package)
end

function M.setup()
	vim.cmd('command SearchPackage lua require"pubspec_assist".start_package_search()')
end

M.close_current_window = ui.close

return M
