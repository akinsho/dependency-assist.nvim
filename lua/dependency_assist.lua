local ui = require 'dependency_assist/ui'
local assistants = require 'dependency_assist/'
local helpers = require 'dependency_assist/helpers'

local M = {}

local function is_centered(buf)
  local ft = vim.bo[buf].filetype
  local center = assistants[ft] ~= nil
  return center
end

--- @param buf integer
local function get_assistant(buf)
  local ft = vim.bo[buf].filetype
  local assistant = assistants[ft]
  -- if we can't get the correct tool based on filetype
  -- check if the dependency file name for the filetype matches
  -- our current file
  if not assistant then
    for filetype, opts in pairs(assistants) do
      if helpers.is_dependency_file(buf, opts.filename) then
        assistant = assistants[filetype]
      end
    end
  end
  if assistant then return assistant end
  helpers.assistant_error()
end

local function insert_package(buf_id, is_dev)
  local assistant = get_assistant(buf_id)
  local pkg = vim.fn.getline('.')
  ui.close()
  if not helpers.is_dependency_file(buf_id, assistant.filename) then
    local filepath = assistant.find_dependency_file(buf_id)
    vim.cmd('e '..filepath)
  end
  assistant.insert_dependency(pkg, is_dev)
end

--- @param buf integer
local function get_package(buf)
  local assistant = get_assistant(buf)
  local pkg = vim.fn.trim(vim.fn.getline('.'))
  if pkg then
    assistant.api.get_package(pkg, function (data)
      local versions = assistant.formatter.format_package_details(data)
      ui.list_window(versions, {
          buf_id = buf,
          center = is_centered(buf),
          on_select = insert_package,
        })
    end)
  end
end

--- @param buf integer
local function search_package(buf)
  local assistant = get_assistant(buf)
  local input = ui.get_current_input()
  if input:len() > 0 then
    assistant.api.search_package(input, function (data)
      local result = {}
      if data then
        for _, pkg in pairs(data.packages) do
          table.insert(result, pkg.package)
        end
        ui.list_window(result, {
            buf_id = buf,
            center = is_centered(buf),
            on_select = get_package,
          })
      end
    end)
  end
end

--- 1. start package search by opening an input buffer, which registers
--- a callback once the a selection is made triggering a searck
function M.dependency_search()
  local buf = vim.api.nvim_get_current_buf()
  ui.input_window(' Package name ', {
      buf_id = buf,
      center = is_centered(buf),
      on_select = search_package
  })
end

local function check_is_setup(buf_id)
  local key = 'dependency_assistant_setup'
  local success, value = pcall(vim.api.nvim_buf_get_var, buf_id, key)
  return success and value or false
end

function M.show_versions(buf_id)
  local assistant = get_assistant(buf_id)
  assistant.show_versions(buf_id,
    function(lnum, version)
      ui.set_virtual_text(buf_id, lnum, version, 'DiffAdd')
    end)
end

--- @param buf_id number
--- @param preferences table
local function setup_dependency_file(buf_id, preferences)
  if preferences and preferences.key then
    vim.api.nvim_buf_set_keymap(buf_id, 'n', preferences.key,
      ':SearchPackage<CR>', { noremap = true, silent = true, })
  end

  M.show_versions(buf_id)

  function _G.__dep_assistant_update_versions()
    M.show_versions(buf_id)
  end

  -- TODO cache the versions so this isn't triggered too often
  -- once caching success fully consider using TextChanged
  vim.cmd('autocmd! BufWritePost <buffer> lua _G.__dep_assistant_update_versions()')
end

--- @param preferences table
local function setup_ft(preferences)
  local buf_id = vim.api.nvim_get_current_buf()
  local already_setup = check_is_setup(buf_id)
  if already_setup then return end

  local assistant = get_assistant(buf_id)
  vim.cmd'command! -buffer SearchPackage lua require"dependency_assist".dependency_search()'

  if helpers.is_dependency_file(buf_id, assistant.filename) then
    setup_dependency_file(buf_id, preferences)
  end
  vim.api.nvim_buf_set_var(buf_id, 'dependency_assistant_setup', true)
end

--- @param preferences table
function M.setup(preferences)
  local names = {}
  for _,data in pairs(assistants) do
    table.insert(names, data.filename)
    table.insert(names, '*.'..data.extension)
  end
  local filenames = table.concat(names, ',')

  function _G.__dep_assistant_setup()
    setup_ft(preferences)
  end

  vim.cmd('autocmd! BufEnter '..filenames..' lua _G.__dep_assistant_setup()')
end

M.close_current_window = ui.close

return M
