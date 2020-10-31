local Api = require'dependency_assist/api'

local M = {}

local api = Api:new({
	base_uri = 'https://pub.dartlang.org/api/',
})

--- @param cb function
function M.get_packages(cb)
	api:get('/packages', function (data)
		if data then
			cb(data)
		else
			vim.cmd('echoerr "No packages found"')
		end
	end)
end

--- @param name string
--- @param cb function
function M.search_package(name, cb)
	api:get('search?q='..name, function (data)
		if data then
			cb(data)
		else
			vim.cmd('echoerr "'..name..'not found"')
		end
	end)
end

function M.get_package(name, cb)
	api:get('/packages/'..name, function(data)
		if data then
			cb(data)
		else
			vim.cmd('echoerr "'..name..'not found"')
		end
	end)
end

return M
