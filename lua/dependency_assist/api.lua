local Api = {
  base_uri = nil,
}

function Api:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

local decode = vim.json and vim.json.decode or vim.fn.json_decode

--- @param path string
--- @param cb function
--- @return number 'the job id'
function Api:get(path, cb)
  return vim.fn.jobstart(
    string.format(
      'curl --compressed -X GET "%s" -H %s',
      self.base_uri .. path,
      '"Content-Type: application/json"'
    ),
    {
      stdout_buffered = true,
      on_stdout = function(_, d, _)
        local json = decode(table.concat(d))
        cb(json)
      end,
    }
  )
end

return Api
