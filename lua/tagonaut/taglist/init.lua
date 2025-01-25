local M = {}

local actions = require "tagonaut.taglist.actions"
local state = require "tagonaut.taglist.state"
local view = require "tagonaut.taglist.view"

local function setup()
  view.setup_highlights()
end


function M.display_tags(workspace_path)
  actions.display_tags(workspace_path)
end

function M.close()
  actions.close()
end

function M.select()
  actions.select()
end

function M.delete()
  actions.delete()
end

function M.clear()
  actions.clear()
end

function M.assign_shortcut()
  actions.assign_shortcut()
end

function M.rename_tag()
  actions.rename_tag()
end

function M.list_tags()
  actions.list_tags()
end

function M.toggle_search()
  actions.toggle_search()
end

function M.is_window_open()
  return state.is_window_open()
end

function M.get_current_workspace()
  return state.get_current_workspace()
end

function M.get_current_tag_list()
  return state.get_current_tag_list()
end

function M.get_current_tag()
  return state.get_current_tag()
end

-- Set up the module when loaded
setup()

return M
