local M = {}
local Popup = require "nui.popup"
local workspace = require "tagonaut.workspace"
local actions = require "tagonaut.workspace.window.actions"
local view = require "tagonaut.workspace.window.view"
local config = require("tagonaut.config").options

local window_state = {
  popup = nil,
  sort_mode = "last_access",
  show_ignored = false,
  search_mode = false,
  search_query = "",
  workspaces = {},
  cursor_pos = 1,
}

local HEADER_OFFSET = 2
local FOOTER_OFFSET = 2

local function create_popup()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  return Popup {
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = " Workspaces ",
        top_align = "center",
      },
    },
    zindex = 40,
    position = "50%",
    size = {
      width = width,
      height = height,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
      bufhidden = "wipe",
      buftype = "nofile",
      swapfile = false,
    },
    win_options = {
      cursorline = true,
      number = false,
      relativenumber = false,
      wrap = false,
      signcolumn = "no",
    },
  }
end

local function update_workspaces_data()
  window_state.workspaces = workspace.get_workspaces_list(window_state.sort_mode, window_state.show_ignored)

  if window_state.search_mode and window_state.search_query ~= "" then
    local filtered = {}
    for _, ws in ipairs(window_state.workspaces) do
      if view.matches_search(ws, window_state.search_query) then
        table.insert(filtered, ws)
      end
    end
    window_state.workspaces = filtered
  end
end

local function setup_keymaps(popup)
  local keymaps = {
    ["<Esc>"] = function()
      M.close_window()
    end,
    ["q"] = function()
      M.close_window()
    end,
    [config.workspace_window.select] = function()
      M.select_workspace()
    end,
    [config.workspace_window.cycle_sort] = function()
      M.cycle_sort_mode()
    end,
    [config.workspace_window.toggle_show_ignored] = function()
      M.toggle_show_ignored()
    end,
    [config.workspace_window.toggle_ignore] = function()
      M.toggle_ignore_current()
    end,
    [config.workspace_window.rename] = function()
      M.rename_current()
    end,
    ["/"] = function()
      M.toggle_search()
    end,
    ["j"] = function()
      M.move_cursor(1)
    end,
    ["k"] = function()
      M.move_cursor(-1)
    end,
    ["<Down>"] = function()
      M.move_cursor(1)
    end,
    ["<Up>"] = function()
      M.move_cursor(-1)
    end,
    ["gg"] = function()
      M.move_cursor_to(1)
    end,
    ["G"] = function()
      M.move_cursor_to(-1)
    end,
  }

  for key, handler in pairs(keymaps) do
    popup:map("n", key, handler, { noremap = true, silent = true })
  end
end

local function restrict_cursor()
  if not window_state.popup or not window_state.popup.winid then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(window_state.popup.winid)
  local line = cursor[1]
  local max_line = #window_state.workspaces + HEADER_OFFSET

  if line <= HEADER_OFFSET then
    vim.api.nvim_win_set_cursor(window_state.popup.winid, { HEADER_OFFSET + 1, 0 })
  elseif line > max_line then
    vim.api.nvim_win_set_cursor(window_state.popup.winid, { max_line, 0 })
  end

  window_state.cursor_pos = vim.api.nvim_win_get_cursor(window_state.popup.winid)[1] - HEADER_OFFSET
end

function M.move_cursor(delta)
  if not window_state.popup or not window_state.popup.winid then
    return
  end

  local new_pos = window_state.cursor_pos + delta
  if new_pos >= 1 and new_pos <= #window_state.workspaces then
    window_state.cursor_pos = new_pos
    vim.api.nvim_win_set_cursor(window_state.popup.winid, { new_pos + HEADER_OFFSET, 0 })
  end
end

function M.move_cursor_to(pos)
  if not window_state.popup or not window_state.popup.winid then
    return
  end

  local target_pos = pos
  if pos < 0 then
    target_pos = #window_state.workspaces
  end

  window_state.cursor_pos = target_pos
  vim.api.nvim_win_set_cursor(window_state.popup.winid, { target_pos + HEADER_OFFSET, 0 })
end

function M.display_workspaces()
  if window_state.popup and window_state.popup.winid then
    return
  end

  local popup = create_popup()
  window_state.popup = popup
  window_state.cursor_pos = 1

  view.setup_highlights()
  setup_keymaps(popup)
  popup:mount()

  local group = vim.api.nvim_create_augroup("TagonautWorkspaceWindow", { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = popup.bufnr,
    callback = restrict_cursor,
  })

  popup:on({ "BufLeave", "WinLeave" }, function()
    if window_state.search_mode then
      window_state.search_mode = false
      window_state.search_query = ""
    end
  end)

  M.update_window()

  vim.schedule(function()
    if #window_state.workspaces > 0 then
      vim.api.nvim_win_set_cursor(popup.winid, { HEADER_OFFSET + 1, 0 })
    end
  end)
end

function M.update_window()
  if not window_state.popup or not window_state.popup.winid then
    return
  end

  update_workspaces_data()
  view.render_content(window_state)

  local title = view.get_window_title(window_state)
  window_state.popup.border:set_text("top", title)

  if #window_state.workspaces > 0 then
    window_state.cursor_pos = math.min(window_state.cursor_pos, #window_state.workspaces)
    window_state.cursor_pos = math.max(window_state.cursor_pos, 1)
    vim.api.nvim_win_set_cursor(window_state.popup.winid, { window_state.cursor_pos + HEADER_OFFSET, 0 })
  end
end

function M.select_workspace()
  local workspace_data = window_state.workspaces[window_state.cursor_pos]
  if workspace_data then
    M.close_window()
    workspace.switch_workspace(workspace_data.path)
  end
end

function M.toggle_ignore_current()
  local workspace_data = window_state.workspaces[window_state.cursor_pos]
  if workspace_data then
    workspace.toggle_ignore_workspace(workspace_data.path)
    M.update_window()
  end
end

function M.rename_current()
  local workspace_data = window_state.workspaces[window_state.cursor_pos]
  if workspace_data then
    local current_name = require("tagonaut.api").workspaces[workspace_data.path].name
      or vim.fn.fnamemodify(workspace_data.path, ":t")

    actions.create_rename_popup(workspace_data.path, current_name, function(new_name)
      if new_name then
        workspace.rename_workspace(workspace_data.path, new_name)
        M.update_window()
      end
    end)
  end
end

function M.close_window()
  if window_state.popup then
    window_state.popup:unmount()
    window_state.popup = nil
  end
end

function M.toggle_search()
  window_state.search_mode = not window_state.search_mode

  if window_state.search_mode then
    actions.search_workspaces(window_state.popup, function(query)
      window_state.search_query = query
      window_state.search_mode = query ~= ""
      M.update_window()
    end)
  else
    window_state.search_query = ""
    M.update_window()
  end
end

function M.cycle_sort_mode()
  window_state.sort_mode = actions.cycle_sort_mode(window_state.sort_mode)
  M.update_window()
end

function M.toggle_show_ignored()
  window_state.show_ignored = not window_state.show_ignored
  M.update_window()
end

function M.get_window_state()
  return window_state
end

return M
