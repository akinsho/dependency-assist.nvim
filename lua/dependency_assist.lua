local M = {}
local api = vim.api
local VIRTUAL_TEXT_HIGHLIGHT = "DependencyAssistVirtualText"

local state = { is_dev = false }

--- @param buf integer
local function get_assistant(buf)
  local h = require("dependency_assist.utils.helpers")
  local assistants = require("dependency_assist.assistants")
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
  if assistant then
    return assistant
  end
  h.assistant_error()
end

local function insert_packages(buf_id, packages)
  local h = require("dependency_assist.utils.helpers")
  local assistant = get_assistant(buf_id)
  require("dependency_assist.ui").close()
  if not h.is_dependency_file(buf_id, assistant.filename) then
    local filepath = assistant.find_dependency_file(buf_id)
    vim.cmd("e " .. filepath)
  end
  assistant.insert_dependencies(packages, state.is_dev)
  state.is_dev = nil
end

--- @param buf integer
function M.get_package(buf, pkg)
  local assistant = get_assistant(buf)
  if pkg then
    assistant.api.get_package(pkg, function(data)
      local versions = assistant.formatter.format_package_details(data)
      if versions then
        require("dependency_assist.ui").list_window(pkg .. " versions", versions, {
          buf_id = buf,
          on_select = insert_packages,
        })
      end
    end)
  end
end

local function select_next_version(versions)
  if not versions then
    return function()
    end
  end
  local indices = {}
  for name, _ in pairs(versions) do
    indices[name] = 1
  end
  return function(package_name, direction)
    local name
    for p, _ in pairs(versions) do
      if string.match(package_name, p) then
        name = p
        break
      end
    end
    if not name or not versions[name] then
      return
    end
    local pkg_versions = versions[name]
    local index = indices[name] + direction
    index = (index < 1 and 1 or index > #pkg_versions and #pkg_versions) or index
    local replacement = pkg_versions[index]
    if not replacement then
      return
    end
    local lnum = vim.fn.line(".")
    local h = require("dependency_assist.utils.helpers")
    h.replace_line(replacement, lnum)
    indices[name] = index
  end
end

--- @param buf integer
--- @param packages table
local function get_latest_versions(buf, packages)
  local assistant = get_assistant(buf)
  assistant.get_packages(packages, function(latest, all_versions)
    require("dependency_assist.ui").list_window("Confirm packages", latest, {
      buf_id = buf,
      on_select = insert_packages,
      on_modify = select_next_version(all_versions),
      modifiable = true,
      subtitle = {
        "You can delete anything you don't want anymore",
        "using 'dd'.",
        "To cycle through versions use 'h' and 'l'",
      },
    })
  end)
end

--- @param buf integer
local function handle_search_results(buf)
  return function(data)
    local assistant = get_assistant(buf)
    if data then
      local selected = assistant.process_search_results(data)
      if #selected > 0 then
        return get_latest_versions(buf, selected)
      else
        local h = require("dependency_assist.utils.helpers")
        h.echomsg("Sorry I couldn't find any matching search results")
      end
    end
  end
end

local function parse_input(input)
  return vim.split(input, ",")
end

--- @param buf integer
--- @param lines table
local function search_packages(buf, lines)
  local ui = require("dependency_assist.ui")
  local assistant = get_assistant(buf)
  ui.close()
  local input = lines[1]
  if #input > 0 then
    ui.loading_window()
    -- force neovim to redraw since using jobwait
    -- prevents this unless explicitly called
    local packages = parse_input(input)
    if #packages > 0 then
      assistant.api.search_multiple_packages(packages, handle_search_results(buf))
    else
      require("dependency_assist.utils.helpers").echomsg('You must enter some packages separated by a ","')
    end
  end
end

--- 1. start package search by opening an input buffer, which registers
--- a callback once a selection is made triggering a search
--- @param is_dev boolean
local function dependency_search(is_dev)
  local ui = require("dependency_assist.ui")
  state.is_dev = is_dev
  ui.set_parent_window(api.nvim_get_current_win())
  local buf = api.nvim_get_current_buf()
  ui.input_window("Enter a package name", {
    subtitle = { "Packages should be separated by a comma" },
    buf_id = buf,
    on_select = search_packages,
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
  local key = "dependency_assistant_setup"
  local success, value = pcall(api.nvim_buf_get_var, buf_id, key)
  return success and value or false
end

function M.show_versions(buf_id)
  local ui = require("dependency_assist.ui")
  local assistant = get_assistant(buf_id)
  -- clear existing virtual text before adding new versions
  ui.clear_virtual_text(buf_id)
  api.nvim_buf_set_var(buf_id, "dependency_versions", {})
  assistant.show_versions(buf_id, function(lnum, version)
    -- setup the buffer variable the first time we open this file
    -- NOTE: confusingly dependency versions can somehow be nil
    -- at this point. If it is reset it to a table
    local success, versions = pcall(api.nvim_buf_get_var, buf_id, "dependency_versions")
    if not success then
      versions = {}
    end
    versions[tostring(lnum)] = version
    api.nvim_buf_set_var(buf_id, "dependency_versions", versions)
    ui.set_virtual_text(buf_id, lnum, version, VIRTUAL_TEXT_HIGHLIGHT)
  end)
end

function M.set_highlights()
  vim.cmd(string.format("highlight %s guifg=LightGreen gui=bold,italic", VIRTUAL_TEXT_HIGHLIGHT))
end

--- @param buf_id number
--- @param preferences table
local function setup_dependency_file(buf_id, preferences)
  if preferences and preferences.key then
    api.nvim_buf_set_keymap(buf_id, "n", preferences.key, "<Cmd>AddDependency<CR>", {
      noremap = true,
      silent = true,
    })
  end

  local h = require("dependency_assist.utils.helpers")
  h.create_cmd("UpdateDependencyLine", "buffer", "upgrade_current_package")

  M.show_versions(buf_id)

  function _G.__dep_assistant_update_versions()
    M.show_versions(buf_id)
  end

  M.set_highlights()
  -- TODO cache the versions so this isn't triggered too often
  -- once caching success fully consider using TextChanged
  h.create_augroups({
    dependency_assist_highlights = {
      {
        "ColorScheme",
        "*",
        [[lua require"dependency_assist".set_highlights()]],
      },
    },
    dependency_assist_update_versions = {
      {
        "BufWritePost",
        "<buffer>",
        [[lua _G.__dep_assistant_update_versions()]],
      },
    },
  })
end

--- @param preferences table
local function setup_ft(preferences)
  local buf_id = api.nvim_get_current_buf()
  local already_setup = check_is_setup(buf_id)
  if already_setup then
    return
  end

  local assistant = get_assistant(buf_id)
  local h = require("dependency_assist.utils.helpers")
  h.create_cmd("AddDependency", "buffer", "dependency_search")
  h.create_cmd("AddDevDependency", "buffer", "dev_dependency_search")

  if h.is_dependency_file(buf_id, assistant.filename) then
    setup_dependency_file(buf_id, preferences)
  end

  api.nvim_buf_set_var(buf_id, "dependency_assistant_setup", true)
end

--- @param preferences table
function M.setup(preferences)
  local assistants = require("dependency_assist.assistants")
  local names = {}
  local filetypes = {}
  for _, data in pairs(assistants) do
    table.insert(names, data.filename)
    table.insert(names, "*." .. data.extension)
    vim.list_extend(filetypes, data.filetypes)
  end
  local filenames = table.concat(names, ",")

  function _G.__dep_assistant_setup()
    -- Specifically ensure that despite a file having the correct extension it is actually
    -- a supported filetype e.g. a special buffer could be created with a name thing.rust with a
    -- filetype of "fake-buf". This should not trigger the plugin
    if vim.tbl_contains(filetypes, vim.bo.filetype) then
      setup_ft(preferences)
    end
  end

  require("dependency_assist.utils.helpers").create_augroups({
    dependency_assist_setup = {
      { "BufEnter", filenames, [[lua _G.__dep_assistant_setup()]] },
    },
  })
end

function M.upgrade_current_package()
  local lnum = vim.fn.line(".")
  local line = vim.fn.getline(".")
  local versions = vim.b.dependency_versions
  local buf_id = api.nvim_get_current_buf()
  local assistant = get_assistant(buf_id)
  if versions then
    local key = tostring(lnum - 1)
    local latest = versions[key]
    if latest then
      local new_line = assistant.formatter.update_version(line, latest)
      if new_line then
        vim.fn.setline(lnum, new_line)
        M.show_versions(buf_id)
      else
        require("dependency_assist.utils.helpers").echomsg("Unable to update package!")
      end
    end
  end
end

M.close_current_window = require("dependency_assist.ui").close

return M
