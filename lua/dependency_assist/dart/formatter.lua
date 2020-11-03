local M = {}

function M.format_packages(content)
  local next_url = content.next_url
  local packages = {}
  for _, pkg in ipairs(content.packages) do
    local str = pkg.name .. ', version: ' .. pkg.latest.version
    table.insert(packages, str)
  end
  return packages, next_url
end

function M.format_package_details(data)
  local result = {}
  if not data or not data.versions then return result end
  for i = #data.versions, 1, -1 do
    local pkg = data.versions[i]
    table.insert(result, pkg.pubspec.name ..": " .. pkg.version)
  end
  return result
end

return M
