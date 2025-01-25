local M = {}
local api = require "tagonaut.api"

M.SORT_MODES = {
  LAST_ACCESS = "last_access",
  NAME = "name",
  PATH = "path",
}

function M.switch_workspace(workspace_path)
  if not vim.fn.isdirectory(workspace_path) then
    vim.notify("Invalid workspace path: " .. workspace_path, vim.log.levels.ERROR)
    return false
  end

  local window = require "tagonaut.workspace.window"
  window.close_window()

  vim.cmd("cd " .. vim.fn.fnameescape(workspace_path))
  api.set_workspace(workspace_path)
  vim.cmd("edit " .. vim.fn.fnameescape(workspace_path))
  vim.notify("Switched to workspace: " .. workspace_path, vim.log.levels.INFO)
  return true
end

function M.get_workspaces_list(sort_mode, show_ignored)
  local workspaces = {}
  for path, data in pairs(api.workspaces) do
    data.ignored = data.ignored or false

    if show_ignored == data.ignored then
      table.insert(workspaces, {
        path = path,
        name = data.name,
        tag_count = vim.tbl_count(data.tags or {}),
        last_accessed = data.last_accessed or 0,
        ignored = data.ignored,
      })
    end
  end

  local sort_functions = {
    [M.SORT_MODES.LAST_ACCESS] = function(a, b)
      return a.last_accessed > b.last_accessed
    end,
    [M.SORT_MODES.NAME] = function(a, b)
      return a.name < b.name
    end,
    [M.SORT_MODES.PATH] = function(a, b)
      return a.path < b.path
    end,
  }

  table.sort(workspaces, sort_functions[sort_mode or M.SORT_MODES.LAST_ACCESS])

  return workspaces
end

function M.toggle_ignore_workspace(workspace_path)
  if api.workspaces[workspace_path] then
    api.workspaces[workspace_path].ignored = not (api.workspaces[workspace_path].ignored or false)
    api.save_tags()
    return api.workspaces[workspace_path].ignored
  end
  return false
end

function M.rename_workspace(workspace_path, new_name)
  if api.workspaces[workspace_path] then
    api.workspaces[workspace_path].name = new_name
    api.save_tags()
    return true
  end
  return false
end

function M.open_workspace_window()
  require("tagonaut.workspace.window").display_workspaces()
end

return M
