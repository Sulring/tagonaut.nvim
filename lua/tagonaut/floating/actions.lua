local M = {}

local api = vim.api
local state = require "tagonaut.floating.state"
local windows = require "tagonaut.floating.windows"
local utils = require "tagonaut.floating.utils"
local tagonaut_api = require "tagonaut.api"
local messages = require "tagonaut.messages"
local symbols = require "tagonaut.symbols"

function M.display_tags(workspace_path)
  if windows.is_window_open() then
    return
  end

  state.set_current_workspace(workspace_path)
  local workspace = tagonaut_api.workspaces[workspace_path]
  if not workspace or not workspace.tags or next(workspace.tags) == nil then
    print(messages.no_tags_available)
    return
  end

  local tag_list = utils.get_sorted_tags(workspace.tags)
  state.set_current_tag_list(tag_list)

  windows.create_main_window(workspace.name or "Tags")

  local lines = utils.format_tag_lines(tag_list)
  local main_buffer = state.get_main_buffer()
  if main_buffer and api.nvim_buf_is_valid(main_buffer) then
    api.nvim_set_option_value("modifiable", true, { buf = main_buffer })
    api.nvim_buf_set_lines(main_buffer, 0, -1, false, lines)
    utils.apply_highlights(main_buffer, lines)
    api.nvim_set_option_value("modifiable", false, { buf = main_buffer })
  end

  if #tag_list > 0 then
    windows.create_preview_window(tag_list[1].info)
  end
end

function M.close()
  windows.close_windows()
end

function M.select()
  if not windows.is_window_open() then
    return
  end

  local main_window = state.get_main_window()
  if not main_window or not api.nvim_win_is_valid(main_window) then
    return
  end

  local cursor = api.nvim_win_get_cursor(main_window)
  local tag_list = state.get_current_tag_list()
  local tag = tag_list[cursor[1]]

  if tag then
    windows.close_windows()
    local success, msg = tagonaut_api.jump_to_tag(tag.id, symbols)
    if not success then
      print(messages.jump_failed(tag.info.name, msg))
    end
  end
end

function M.delete()
  if not windows.is_window_open() then
    return
  end

  local main_window = state.get_main_window()
  if not main_window or not api.nvim_win_is_valid(main_window) then
    return
  end

  local cursor = api.nvim_win_get_cursor(main_window)
  local tag_list = state.get_current_tag_list()
  local tag = tag_list[cursor[1]]

  if tag then
    local success, msg = tagonaut_api.delete_tag(tag.id)
    if success then
      local workspace = tagonaut_api.workspaces[state.get_current_workspace()]
      local new_tag_list = utils.get_sorted_tags(workspace.tags)
      state.set_current_tag_list(new_tag_list)

      windows.update_main_window()
      if #new_tag_list > 0 then
        local new_cursor = { math.min(cursor[1], #new_tag_list), 0 }
        api.nvim_win_set_cursor(main_window, new_cursor)
        windows.create_preview_window(new_tag_list[new_cursor[1]].info)
      else
        windows.close_windows()
      end
    end
    print(msg)
  end
end

function M.clear()
  vim.ui.input({ prompt = messages.confirm_clear_tags }, function(input)
    if input and input:lower() == "y" then
      local success, msg = tagonaut_api.clear_all_tags()
      if success then
        windows.close_windows()
      end
      print(msg)
    end
  end)
end

function M.assign_shortcut()
  if not windows.is_window_open() then
    return
  end

  local main_window = state.get_main_window()
  if not main_window or not api.nvim_win_is_valid(main_window) then
    return
  end

  local cursor = api.nvim_win_get_cursor(main_window)
  local tag_list = state.get_current_tag_list()
  local tag = tag_list[cursor[1]]

  if tag then
    vim.ui.input({ prompt = messages.assign_shortcut_prompt }, function(input)
      if input and input ~= "" then
        local success, msg = tagonaut_api.set_shortcut(tag.id, input)
        if success then
          local workspace = tagonaut_api.workspaces[state.get_current_workspace()]
          local new_tag_list = utils.get_sorted_tags(workspace.tags)
          state.set_current_tag_list(new_tag_list)

          windows.update_main_window()
        end
        print(msg)
      end
    end)
  end
end

function M.rename_tag()
  if not windows.is_window_open() then
    return
  end

  local main_window = state.get_main_window()
  if not main_window or not api.nvim_win_is_valid(main_window) then
    return
  end

  local cursor = api.nvim_win_get_cursor(main_window)
  local tag_list = state.get_current_tag_list()
  local tag = tag_list[cursor[1]]

  if tag then
    vim.ui.input({ prompt = messages.rename_tag_prompt }, function(input)
      if input and input ~= "" then
        local success = tagonaut_api.rename_tag(tag.id, input)
        if success then
          M.display_tags(state.get_current_workspace())
        end
      end
    end)
  end
end

function M.list_tags()
  local workspace = tagonaut_api.get_workspace()
  M.display_tags(workspace)
end

return M
