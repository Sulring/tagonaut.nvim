local M = {}
local config = require("tagonaut.config").options

local state = {
  popup = nil,
  preview_popup = nil,
  legend_popup = nil,

  current_workspace = nil,
  current_tag_list = {},
  cursor_pos = 1,

  sort_mode = "name",
  show_preview = true,

  minimal_mode = config.minimal,
  show_legend = config.show_legend,
}

M.HEADER_ROWS = 2
M.FOOTER_ROWS = 2

function M.get_popup()
  return state.popup
end

function M.get_preview_popup()
  return state.preview_popup
end

function M.get_legend_popup()
  return state.legend_popup
end

function M.set_popup(popup)
  state.popup = popup
end

function M.set_preview_popup(popup)
  state.preview_popup = popup
end

function M.set_legend_popup(popup)
  state.legend_popup = popup
end

function M.get_current_workspace()
  return state.current_workspace
end

function M.get_current_tag_list()
  return state.current_tag_list
end

function M.get_cursor_position()
  return state.cursor_pos
end

function M.set_current_workspace(workspace)
  state.current_workspace = workspace
end

function M.set_current_tag_list(tag_list)
  state.current_tag_list = tag_list
end

function M.set_cursor_position(pos)
  local max_pos = #state.current_tag_list
  pos = math.max(1, math.min(pos, max_pos))
  state.cursor_pos = pos
end

function M.get_minimal_mode()
  return state.minimal_mode
end

function M.get_show_legend()
  return state.show_legend
end

function M.toggle_minimal_mode()
  state.minimal_mode = not state.minimal_mode
  if state.minimal_mode then
    state.show_preview = false
  end
  return state.minimal_mode
end

function M.toggle_legend()
  state.show_legend = not state.show_legend
  return state.show_legend
end

function M.get_sort_mode()
  return state.sort_mode
end

function M.get_show_preview()
  return state.show_preview and not state.minimal_mode
end

function M.set_sort_mode(mode)
  state.sort_mode = mode
end

function M.set_show_preview(show)
  state.show_preview = show
end

function M.get_current_tag()
  if #state.current_tag_list > 0 and state.cursor_pos >= 1 and state.cursor_pos <= #state.current_tag_list then
    local tag = state.current_tag_list[state.cursor_pos]
    return tag
  end
  return nil
end

function M.reset()
  state.popup = nil
  state.preview_popup = nil
  state.legend_popup = nil
  state.current_workspace = nil
  state.current_tag_list = {}
  state.cursor_pos = 1
  state.sort_mode = "name"
  state.show_preview = true
end

function M.is_window_open()
  return state.popup ~= nil and state.popup.bufnr and vim.api.nvim_buf_is_valid(state.popup.bufnr)
end

function M.is_preview_open()
  return state.preview_popup ~= nil
    and state.preview_popup.bufnr
    and vim.api.nvim_buf_is_valid(state.preview_popup.bufnr)
end

function M.get_buffer_line_for_cursor()
  return state.minimal_mode and state.cursor_pos or (state.cursor_pos + M.HEADER_ROWS)
end

function M.buffer_line_to_cursor_position(buffer_line)
  return state.minimal_mode and buffer_line or (buffer_line - M.HEADER_ROWS)
end

function M.is_valid_tag_line(buffer_line)
  local tag_start = state.minimal_mode and 1 or (M.HEADER_ROWS + 1)
  local tag_end = tag_start + #state.current_tag_list - 1
  return buffer_line >= tag_start and buffer_line <= tag_end
end

return M
