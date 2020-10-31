local base_uri = 'https://pub.dartlang.org/api/'
local M = {}

--- @param path string
--- @param cb function
function M.get(path, cb)
	vim.fn.jobstart(
		string.format('curl -X GET "%s" -H %s', base_uri .. path, '"Content-Type: application/json"'),
		{
			stdout_buffered = true,
			on_stdout =
			function(_, d, _)
				local json = vim.fn.json_decode(table.concat(d))
				cb(json)
			end,
		})
end



--- @param cb function
function M.get_packages(cb)
	M.get('/packages', function (data)
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
	M.get('search?q='..name, function (data)
		if data then
			cb(data)
		else
			vim.cmd('echoerr "'..name..'not found"')
		end
	end)
end

function M.get_package(name, cb)
	M.get('/packages/'..name, function(data)
		if data then
			cb(data)
		else
			vim.cmd('echoerr "'..name..'not found"')
		end
	end)
end

return M
