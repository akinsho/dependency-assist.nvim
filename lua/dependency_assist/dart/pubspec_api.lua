local Api = require("dependency_assist/api")

local M = {}

local api = Api:new({
  base_uri = "https://pub.dartlang.org/api/",
})

--- @param name string
--- @param cb function
--- @return integer
function M.search_package(name, cb)
  return api:get("search?q=" .. name, function(data)
    if data then
      cb(data)
    else
      local helpers = require("dependency_assist/utils/helpers")
      helpers.echoerr(name .. "not found")
    end
  end)
end

function M.search_multiple_packages(packages, cb)
  local jobs = {}
  local result = {}
  for i, pkg in ipairs(packages) do
    jobs[i] = M.search_package(pkg, function(data)
      result[pkg] = data
    end)
  end
  vim.fn.jobwait(jobs, -1)
  cb(result)
end

function M.get_package(name, cb)
  return api:get("/packages/" .. name, function(data)
    if data then
      cb(data)
    else
      local helpers = require("dependency_assist/utils/helpers")
      helpers.echoerr(name .. "not found")
    end
  end)
end

function M.get_packages(names, cb)
  local jobs = {}
  local result = {}
  for i, name in ipairs(names) do
    jobs[i] = M.get_package(name, function(data)
      result[name] = data
    end)
  end
  vim.fn.jobwait(jobs, -1)
  cb(result)
end

function M.check_outdated_packages(deps, cb)
  for name, version in pairs(deps) do
    if type(version) == "string" then
      M.get_package(name, function(data)
        if data and data.latest then
          local latest = data.latest.version
          -- TODO this doesn't match anything that is quoted
          -- the format string works but also breaks non-quoted strings
          -- local previous = string.format("%q", pkg.previous)
          if latest ~= version:gsub("%^", "") then
            cb({ name = name, latest = latest, previous = version })
          end
        else
          -- TODO inform of error
        end
      end)
    end
  end
end

return M
