local M = {}
local api = vim.api
local state = require "tagonaut.floating.state"

local function get_workspace_at_cursor()
  local win = state.get_main_window()
  if not win or not api.nvim_win_is_valid(win) then
    return nil
  end

  local cursor = api.nvim_win_get_cursor(win)
  if not cursor or cursor[1] <= 2 then
    return nil
  end

  return state.workspace_list[cursor[1] - 2]
end

function M.select_workspace()
  local workspace_entry = get_workspace_at_cursor()
  if workspace_entry then
    if #vim.api.nvim_list_wins() == 1 then
      vim.cmd "vsplit"
      vim.cmd "wincmd l"
    else
      vim.cmd "wincmd p"
    end

    local workspace = require "tagonaut.workspace"
    workspace.switch_workspace(workspace_entry.path)

    local win = state.get_main_window()
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      state.set_main_window(nil)
      state.set_main_buffer(nil)
    end
  end
end

function M.cycle_sort_mode(current_mode)
  local workspace = require "tagonaut.workspace"
  local modes = workspace.SORT_MODES
  local order = { modes.LAST_ACCESS, modes.NAME, modes.PATH }

  for i, mode in ipairs(order) do
    if mode == current_mode then
      return order[i % #order + 1]
    end
  end

  return order[1]
end

function M.toggle_ignore_current()
  local workspace_entry = get_workspace_at_cursor()
  if workspace_entry then
    local workspace = require "tagonaut.workspace"
    local is_ignored = workspace.toggle_ignore_workspace(workspace_entry.path)
    vim.notify(
      string.format("Workspace '%s' is now %s", workspace_entry.name, is_ignored and "ignored" or "no longer ignored")
    )
  end
end

function M.rename_current(callback)
  local workspace_entry = get_workspace_at_cursor()
  if workspace_entry then
    vim.ui.input({
      prompt = "New workspace name: ",
      default = workspace_entry.name,
    }, function(new_name)
      if new_name and new_name ~= "" then
        local workspace = require "tagonaut.workspace"
        if workspace.rename_workspace(workspace_entry.path, new_name) then
          callback()
        end
      end
    end)
  end
end

return M
