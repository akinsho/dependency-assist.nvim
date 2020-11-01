local ui = require 'dependency_assist/ui'
local assistants = require 'dependency_assist/'
local helpers = require 'dependency_assist/helpers'

local M = {}

local function is_centered(buf)
  local ft = vim.bo[buf].filetype
  local center = assistants[ft] ~= nil
  return center
end


local function insert_package()
  local pkg = vim.fn.getline('.')
  ui.close()
  helpers.insert_at_cursor_pos(pkg)
end

--- @param buf integer
local function get_assist(buf)
  local ft = vim.bo[buf].filetype
  local assist = assistants[ft]
  -- if we can't get the correct tool based on filetype
  -- check if the dependency file name for the filetype matches
  -- our current file
  if not assist then
    local fname = vim.fn.expand('#'..buf..':t')
    for filetype, opts in pairs(assistants) do
      if fname == opts.filename then
        assist = assistants[filetype]
      end
    end
  end
  if assist then return assist end
  helpers.assist_error()
end

--- @param buf integer
local function get_package(buf)
  local assist = get_assist(buf)
  local pkg = vim.fn.trim(vim.fn.getline('.'))
  if pkg then
    assist.api.get_package(pkg, function (data)
      local versions = assist.formatter.format_package_details(data)
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
  local assist = get_assist(buf)
  local input = ui.get_current_input()
  if input:len() > 0 then
    assist.api.search_package(input, function (data)
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
function M.start_package_search()
  local buf = vim.api.nvim_get_current_buf()
  ui.input_window(' Package name ', {
      buf_id = buf,
      center = is_centered(buf),
      on_select = search_package
  })
end

--- @param preferences table
function M.setup_ft(preferences)
  vim.cmd('command! -buffer SearchPackage lua require"dependency_assist".start_package_search()')

  local key = (preferences and preferences.key or nil)
  if not key then return end

  local buf_id = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_keymap(buf_id, 'n', key, ':SearchPackage<CR>',
    {
      noremap = true,
      silent = true,
    })

  local assist = get_assist(buf_id)
  return assist.show_versions(
    buf_id,
    function(lnum, version)
      ui.set_virtual_text(buf_id, lnum, version, 'DiffAdd')
    end)
end

--- @param preferences table
function M.setup(preferences)
  local names = {}
  local fts = {}
  for ft,data in pairs(assistants) do
    table.insert(names, data.filename)
    table.insert(fts, ft)
  end
  local filenames = table.concat(names, ',')
  local filetypes = table.concat(fts, ',')

  function _G.__dep_assist_ft_setup()
    M.setup_ft(preferences)
  end

  vim.cmd('autocmd! BufEnter '..filenames..' lua _G.__dep_assist_ft_setup()')
  vim.cmd('autocmd! FileType '..filetypes..' lua _G.__dep_assist_ft_setup()')
end

M.close_current_window = ui.close

return M
