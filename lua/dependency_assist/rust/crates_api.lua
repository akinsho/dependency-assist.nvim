local Api = require("dependency_assist.api")

local M = {}

local api = Api:new({ base_uri = "https://crates.io/api/v1" })

--- @param name string
--- @param cb function
--- @return integer
function M.search_package(name, cb)
  return api:get("/crates?q=" .. name, function(data)
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
  return api:get("/crates/" .. name, function(data)
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
      M.get_package(name, cb)
    end
  end
end

return M
