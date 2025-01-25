local M = {}

local state = {
  main_window = nil,
  main_buffer = nil,
  preview_window = nil,
  preview_buffer = nil,
  current_workspace = nil,
  legend_window = nil,
  legend_buffer = nil,
  current_tag_list = {},
}

function M.get_main_window()
  return state.main_window
end

function M.get_main_buffer()
  return state.main_buffer
end

function M.get_preview_window()
  return state.preview_window
end

function M.get_preview_buffer()
  return state.preview_buffer
end

function M.get_current_workspace()
  return state.current_workspace
end

function M.get_current_tag_list()
  return state.current_tag_list
end

function M.set_main_window(window)
  state.main_window = window
end

function M.set_main_buffer(buffer)
  state.main_buffer = buffer
end

function M.set_preview_window(window)
  state.preview_window = window
end

function M.set_preview_buffer(buffer)
  state.preview_buffer = buffer
end

function M.set_current_workspace(workspace)
  state.current_workspace = workspace
end

function M.set_current_tag_list(tag_list)
  state.current_tag_list = tag_list
end

function M.get_legend_window()
  return state.legend_window
end

function M.get_legend_buffer()
  return state.legend_buffer
end

function M.set_legend_window(window)
  state.legend_window = window
end

function M.set_legend_buffer(buffer)
  state.legend_buffer = buffer
end

function M.reset()
  state.main_window = nil
  state.main_buffer = nil
  state.preview_window = nil
  state.preview_buffer = nil
  state.current_workspace = nil
  state.legend_window = nil
  state.legend_buffer = nil
  state.current_tag_list = {}
end

return M
