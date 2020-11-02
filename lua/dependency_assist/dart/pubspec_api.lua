local Api = require'dependency_assist/api'
local helpers = require'dependency_assist/helpers'

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
      helpers.echoerr("No packages found")
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
      helpers.echoerr(name..'not found')
    end
  end)
end

function M.get_package(name, cb)
  api:get('/packages/'..name, function(data)
    if data then
      cb(data)
    else
      helpers.echoerr(name..'not found')
    end
  end)
end

function M.check_outdated_packages(deps, cb)
  for name,version in pairs(deps) do
    if type(version) ~= 'string' then goto continue end
    M.get_package(name, function (data)
      if data and data.latest then
        local latest = data.latest.version
        -- TODO this doesn't match anything that is quoted
        -- the format string works but also breaks non-quoted strings
        -- local previous = string.format("%q", pkg.previous)
        if latest ~= version:gsub('%^', '') then
          cb({
              name = name,
              latest = latest,
              previous = version,
            })
        end
      else
        -- TODO inform of error
      end
    end)
    ::continue::
  end
end

return M
