local Api = {
  base_uri = nil
}

function Api:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

--- @param path string
--- @param cb function
function Api:get(path, cb)
  vim.fn.jobstart(
    string.format('curl -X GET "%s" -H %s', self.base_uri .. path, '"Content-Type: application/json"'),
    {
      stdout_buffered = true,
      on_stdout =
      function(_, d, _)
        local json = vim.fn.json_decode(table.concat(d))
        cb(json)
      end,
    })
end

return Api
