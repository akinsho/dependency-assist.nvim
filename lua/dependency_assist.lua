local ui = require 'dependency_assist/ui'
local assistants = require 'dependency_assist/'
local h = require 'dependency_assist/utils/helpers'
require 'dependency_assist/utils/levenshtein_distance'

local M = {}
local api = vim.api
local SIMILARITY_THRESHOLD = 4

local state = { is_dev = false }

--- @param buf integer
local function get_assistant(buf)
  local ft = vim.bo[buf].filetype
  local assistant = assistants[ft]
  -- if we can't get the correct tool based on filetype
  -- check if the dependency file name for the filetype matches
  -- our current file
  if not assistant then
    for filetype, opts in pairs(assistants) do
      if h.is_dependency_file(buf, opts.filename) then
        assistant = assistants[filetype]
      end
    end
  end
  if assistant then return assistant end
  h.assistant_error()
end

local function insert_package(buf_id, pkg)
  local assistant = get_assistant(buf_id)
  ui.close()
  if not h.is_dependency_file(buf_id, assistant.filename) then
    local filepath = assistant.find_dependency_file(buf_id)
    vim.cmd('e '..filepath)
  end
  assistant.insert_dependency(pkg, state.is_dev)
  state.is_dev = nil
end

--- @param buf integer
local function get_package(buf, pkg)
  local assistant = get_assistant(buf)
  if pkg then
    assistant.api.get_package(pkg, function (data)
      local versions = assistant.formatter.format_package_details(data)
      if versions then
        ui.list_window(pkg..' versions', versions, {
            buf_id = buf,
            on_select = insert_package,
          })
      end
    end)
  end
end

--- @param buf integer
local function search_package(buf)
  local assistant = get_assistant(buf)
  local input = ui.get_current_input()
  ui.close()
  if input:len() > 0 then
    ui.loading_window()
    assistant.api.search_package(input, function (data)
      local result = {}
      if data then
        local match
        for _, pkg in pairs(data.packages) do
          local distance = string.levenshtein(input, pkg.package)
          if distance < SIMILARITY_THRESHOLD then
            match = pkg.package
            break
          end
          table.insert(result, pkg.package)
        end
        if match then
          get_package(buf, match)
        else
          ui.list_window('Query: '..input, result, {
              buf_id = buf,
              on_select = get_package,
            })
        end
      end
    end)
  end
end

--- 1. start package search by opening an input buffer, which registers
--- a callback once a selection is made triggering a search
--- @param is_dev boolean
local function dependency_search(is_dev)
  state.is_dev = is_dev
  ui.set_parent_window(api.nvim_get_current_win())
  local buf = api.nvim_get_current_buf()
  ui.input_window('Enter a package name', {
      buf_id = buf,
      on_select = search_package
  })
end

-- TODO if the booleans could be passed to the
-- commands directly these would not be necessary
-- although passing args to `vim.cmd` does not work
-- for some reason
function M.dev_dependency_search()
  dependency_search(true)
end

function M.dependency_search()
  dependency_search(false)
end

local function check_is_setup(buf_id)
  local key = 'dependency_assistant_setup'
  local success, value = pcall(api.nvim_buf_get_var, buf_id, key)
  return success and value or false
end

function M.show_versions(buf_id)
  local assistant = get_assistant(buf_id)
  assistant.show_versions(buf_id,
    function(lnum, version)
      ui.set_virtual_text(buf_id, lnum, version, 'DependencyAssistVirtText')
    end)
end

function M.set_highlights()
  vim.cmd('highlight DependencyAssistVirtText guifg=LightGreen gui=bold,italic')
end

--- @param buf_id number
--- @param preferences table
local function setup_dependency_file(buf_id, preferences)
  if preferences and preferences.key then
    api.nvim_buf_set_keymap(buf_id, 'n', preferences.key, ':AddDependency<CR>', {
        noremap = true,
        silent = true,
      })
  end

  M.show_versions(buf_id)

  function _G.__dep_assistant_update_versions()
    M.show_versions(buf_id)
  end

  M.set_highlights()
  -- TODO cache the versions so this isn't triggered too often
  -- once caching success fully consider using TextChanged
  h.create_augroups({
      dependency_assist_highlights = {
        {'ColorScheme', '*', [[lua require"dependency_assist".set_highlights()]]}
      };
      dependency_assist_update_versions = {
        {'BufWritePost', '<buffer>', [[lua _G.__dep_assistant_update_versions()]]}
      }
    })
end

--- @param preferences table
local function setup_ft(preferences)
  local buf_id = api.nvim_get_current_buf()
  local already_setup = check_is_setup(buf_id)
  if already_setup then return end

  local assistant = get_assistant(buf_id)
  h.create_cmd('AddDependency', 'buffer', 'dependency_search')
  h.create_cmd('AddDevDependency', 'buffer', 'dev_dependency_search')

  if h.is_dependency_file(buf_id, assistant.filename) then
    setup_dependency_file(buf_id, preferences)
  end

  api.nvim_buf_set_var(buf_id, 'dependency_assistant_setup', true)
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

  h.create_augroups({
    dependency_assist_setup = {
      {'BufEnter', filenames, [[lua _G.__dep_assistant_setup()]]}
    }
  })
end

M.close_current_window = ui.close

return M
