local M = {}

function M.format_packages(content)
	local next_url = content.next_url
	local packages = {}
	for _,package in ipairs(content.packages) do
		local str = package.name .. ', version: ' .. package.latest.version
		table.insert(packages, str)
	end
	return packages, next_url
end

function M.format_package_details(data)
	local result = {}
	for i = #data.versions, 1, -1 do
		local pkg = data.versions[i]
		table.insert(result, pkg.pubspec.name ..": " .. pkg.version)
	end
	return result
end

return M
