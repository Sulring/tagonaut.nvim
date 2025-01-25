local M = {}
local state = require "tagonaut.floating.state"
local view = require "tagonaut.workspace.window.view"
local actions = require "tagonaut.workspace.window.actions"

local window_state = {
  sort_mode = "last_access",
  show_ignored = false,
}

function M.update_window()
  local win = state.get_main_window()
  local buf = state.get_main_buffer()

  if not win or not vim.api.nvim_win_is_valid(win) or not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local workspace = require "tagonaut.workspace"
  state.workspace_list = workspace.get_workspaces_list(window_state.sort_mode, window_state.show_ignored)

  local dimensions = require("tagonaut.workspace.window.utils").calculate_dimensions(#state.workspace_list)
  view.update_window_content(buf, win, dimensions, window_state)
end

function M.display_workspaces()
  local existing_win = state.get_main_window()
  if existing_win and vim.api.nvim_win_is_valid(existing_win) then
    return
  end

  state.set_main_window(nil)
  state.set_main_buffer(nil)

  local workspace = require "tagonaut.workspace"
  state.workspace_list = workspace.get_workspaces_list(window_state.sort_mode, window_state.show_ignored)

  view.create_window(window_state)
end

function M.select_workspace()
  actions.select_workspace()
end

function M.cycle_sort_mode()
  window_state.sort_mode = actions.cycle_sort_mode(window_state.sort_mode)
  vim.schedule(function()
    M.update_window()
    vim.cmd "redraw"
  end)
end

function M.toggle_show_ignored()
  window_state.show_ignored = not window_state.show_ignored
  M.update_window()
end

function M.toggle_ignore_current()
  actions.toggle_ignore_current()
  M.update_window()
end

function M.rename_current()
  actions.rename_current(function()
    M.update_window()
  end)
end

return M
