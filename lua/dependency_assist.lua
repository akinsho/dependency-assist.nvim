local ui = require 'dependency_assist/ui'
local supported_filetypes = require 'dependency_assist/supported_fts'
local helpers = require 'dependency_assist/helpers'

local M = {}

local function insert_package()
  local pkg = vim.fn.getline('.')
  ui.close()
  helpers.insert_at_cursor_pos(pkg)
end

--- @param buf integer
local function get_assist(buf)
  local ft = vim.bo[buf].filetype
  local assist = supported_filetypes[ft]
  -- we can't get the correct tool based on filetype
  -- check if the filename for the filetype matches
  -- our current file
  if not assist then
    local fname = vim.fn.expand('#'..buf..':t')
    for filetype, opts in pairs(supported_filetypes) do
      if fname == opts.filename then
        assist = supported_filetypes[filetype]
      end
    end
  end
  if assist then return assist end
  helpers.assist_error()
end

--- @param assist table
local function get_package(assist)
  local pkg = vim.fn.trim(vim.fn.getline('.'))
  if pkg then
    assist.api.get_package(pkg, function (data)
      local versions = assist.formatter.format_package_details(data)
      ui.list_window(versions, insert_package)
    end)
  end
end

--- @param assist table
local function search_package(assist)
  local input = ui.get_current_input()
  if input:len() > 0 then
    assist.api.search_package(input, function (data)
      local result = {}
      if data then
        for _, pkg in pairs(data.packages) do
          table.insert(result, pkg.package)
        end
        ui.list_window(result, function()
          get_package(assist)
        end)
      end
    end)
  end
end

--- 1. start package search by opening an input buffer, which registers
--- a callback once the a selection is made triggering a searck
function M.start_package_search()
  local buf = vim.api.nvim_get_current_buf()
  local assist = get_assist(buf)
  ui.input_window(' Package name ', function()
    search_package(assist)
  end)
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
  local fts = {}
  for _,ft in pairs(supported_filetypes) do
    table.insert(fts, ft.filename)
  end
  local all_fts = table.concat(fts, ',')

  function _G.__dep_assist_ft_setup()
    M.setup_ft(preferences)
  end

  vim.cmd('autocmd! BufEnter '..all_fts..' lua _G.__dep_assist_ft_setup()')
end

M.close_current_window = ui.close

return M
