local ui = require 'dependency_assist/ui'
local assistants = require 'dependency_assist/'
local h = require 'dependency_assist/utils/helpers'
require 'dependency_assist/utils/levenshtein_distance'

local M = {}
local api = vim.api
local VIRTUAL_TEXT_HIGHLIGHT = 'DependencyAssistVirtualText'

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

local function insert_packages(buf_id, packages)
  local assistant = get_assistant(buf_id)
  ui.close()
  if not h.is_dependency_file(buf_id, assistant.filename) then
    local filepath = assistant.find_dependency_file(buf_id)
    vim.cmd('e '..filepath)
  end
  assistant.insert_dependencies(packages, state.is_dev)
  state.is_dev = nil
end

--- @param buf integer
function M.get_package(buf, pkg)
  local assistant = get_assistant(buf)
  if pkg then
    assistant.api.get_package(pkg, function (data)
      local versions = assistant.formatter.format_package_details(data)
      if versions then
        ui.list_window(pkg..' versions', versions, {
            buf_id = buf,
            on_select = function(buf_id, pkg)
              insert_packages(buf_id, pkg)
            end
          })
      end
    end)
  end
end

--- @param buf integer
--- @param packages table
local function get_latest_versions(buf, packages)
  local assistant = get_assistant(buf)
  assistant.api.get_packages(packages, function(data)
    local all_latest = {}
    for _, result in pairs(data) do
      local versions = assistant.formatter.format_package_details(result)
      table.insert(all_latest, versions[1])
    end

    ui.list_window('Confirm packages', all_latest, {
        buf_id = buf,
        on_select = insert_packages,
        modifiable = true,
      })
  end)
end

--- @param buf integer
local function handle_search_results(buf)
  return function(data)
    if data then
      local selected = {}
      for input, result in pairs(data) do
        local match
        local score
        for _, pkg in ipairs(result.packages) do
          local distance = string.levenshtein(input, pkg.package)
          if score == nil or distance < score then
            score = distance
            match = pkg.package
          end
        end
        table.insert(selected, match)
      end
      if #selected > 0 then
        return get_latest_versions(buf, selected)
      else
        h.echomsg("Sorry I couldn't find any matching search results")
      end
    end
  end
end

local function parse_input(input)
  return vim.split(input, ',' )
end

--- @param buf integer
--- @param lines table
local function search_packages(buf, lines)
  local assistant = get_assistant(buf)
  ui.close()
  local input = lines[1]
  if input:len() > 0 then
    ui.loading_window()
    -- force neovim to redraw since using jobwait
    -- prevents this unless explicitly called
    local packages = parse_input(input)
    if #packages > 0 then
      assistant.api.search_multiple_packages(
        packages,
        handle_search_results(buf)
      )
    else
      h.echomsg('You must enter some packages separated by a ","')
    end
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
      on_select = search_packages
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
  -- clear existing virtual text before adding new versions
  ui.clear_virtual_text(buf_id)
  assistant.show_versions(buf_id,
    function(lnum, version)
      ui.set_virtual_text(buf_id, lnum, version, VIRTUAL_TEXT_HIGHLIGHT)
    end)
end

function M.set_highlights()
  vim.cmd(
    string.format(
      'highlight %s guifg=LightGreen gui=bold,italic',
      VIRTUAL_TEXT_HIGHLIGHT
    )
  )
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
