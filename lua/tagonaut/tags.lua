local M = {}
local api = require "tagonaut.api"
local messages = require "tagonaut.messages"
local extmarks = require "tagonaut.extmarks"

function M.setup_autocmds()
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    callback = function(ev)
      extmarks.update_extmarks(ev.buf, api.workspaces)
    end,
  })
end

function M.goto_next_tag(direction)
  local current_file = vim.fn.expand "%:p"
  local current_line = vim.fn.line "."
  local workspace = api.get_workspace()

  if not api.workspaces[workspace] or not api.workspaces[workspace].tags then
    print(messages.no_tags_available)
    return
  end

  local utils = require "tagonaut.utils"
  local tags_array = utils.get_sorted_tags(api.workspaces[workspace].tags)

  local current_index = nil
  local closest_index = nil
  local min_diff = math.huge

  for i, tag in ipairs(tags_array) do
    if tag.info.path == current_file then
      if tag.info.line == current_line then
        current_index = i
        break
      else
        local diff = math.abs(tag.info.line - current_line)
        if diff < min_diff then
          min_diff = diff
          closest_index = i
        end
      end
    end
  end

  local start_index = current_index or closest_index
  if not start_index then
    start_index = 1
  end

  local next_index = start_index + direction
  if next_index < 1 then
    next_index = #tags_array
  elseif next_index > #tags_array then
    next_index = 1
  end

  if tags_array[next_index] then
    local next_tag = tags_array[next_index]
    vim.cmd("edit " .. next_tag.info.path)
    vim.api.nvim_win_set_cursor(0, { next_tag.info.line, 0 })
    vim.cmd "normal! zz"
    print(messages.jumped_to_tag(next_tag.info.name))
  else
    print(messages.no_more_tags)
  end
end

function M.toggle_extmarks()
  local workspace = api.get_workspace()

  if not workspace then
    print "No valid workspace found"
    return
  end

  if not api.workspaces[workspace] then
    local workspace_name = api.get_workspace_name(workspace)
    if not workspace_name then
      print "Could not get workspace name"
      return
    end

    api.workspaces[workspace] = {
      name = workspace_name,
      counter = 0,
      tags = {},
    }
  end

  api.workspaces[workspace].extmarks_visible = not (api.workspaces[workspace].extmarks_visible or false)

  if api.workspaces[workspace].extmarks_visible then
    api.update_extmarks()
    print "Tags are now visible"
  else
    extmarks.clear_all_extmarks()
    print "Tags are now hidden"
  end

  api.save_tags()
end

--- Find tag at current cursor position
-- @return number|nil: Tag ID if found, nil otherwise
function M.find_tag_at_cursor()
  local current_file = vim.fn.expand "%:p"
  local current_line = vim.fn.line "."
  local workspace = api.get_workspace()

  if api.workspaces[workspace] and api.workspaces[workspace].tags then
    for id, info in pairs(api.workspaces[workspace].tags) do
      if info.path == current_file and info.line == current_line then
        return id
      end
    end
  end
  return nil
end

--- Get the next tag ID in sequence
-- @param current_id number: The current tag ID
-- @param direction number: Direction (1 for next, -1 for previous)
-- @return number|nil: Next tag ID if found, nil otherwise
function M.get_next_tag_id(current_id, direction)
  local workspace = api.get_workspace()
  if not api.workspaces[workspace] or not api.workspaces[workspace].tags then
    return nil
  end

  local tags_array = {}
  for id, _ in pairs(api.workspaces[workspace].tags) do
    table.insert(tags_array, id)
  end
  table.sort(tags_array)

  local current_index = nil
  for i, id in ipairs(tags_array) do
    if id == current_id then
      current_index = i
      break
    end
  end

  if not current_index then
    return tags_array[1]
  end

  local next_index = current_index + direction
  if next_index < 1 then
    next_index = #tags_array
  elseif next_index > #tags_array then
    next_index = 1
  end

  return tags_array[next_index]
end

return M
