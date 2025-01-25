local M = {}
local Input = require "nui.input"
local workspace = require "tagonaut.workspace"

M.SORT_MODES = workspace.SORT_MODES

function M.cycle_sort_mode(current_mode)
  local modes = M.SORT_MODES
  local order = { modes.LAST_ACCESS, modes.NAME, modes.PATH }

  for i, mode in ipairs(order) do
    if mode == current_mode then
      return order[i % #order + 1]
    end
  end

  return order[1]
end

local function create_input_popup(opts)
  return Input({
    relative = opts.relative or "cursor",
    position = opts.position or {
      row = opts.row or "50%",
      col = opts.col or "50%",
    },
    size = {
      width = opts.width or 40,
    },
    border = {
      style = "rounded",
      text = {
        top = opts.title,
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Special",
    },
    zindex = opts.zindex or 10,
  }, {
    prompt = opts.prompt or "> ",
    default_value = opts.default_value or "",
    on_submit = opts.on_submit,
    on_close = opts.on_close,
  })
end

function M.create_rename_popup(workspace_path, current_name, callback)
  local input = create_input_popup {
    title = " Rename Workspace ",
    default_value = current_name,
    relative = "editor",
    position = {
      row = "50%",
      col = "50%",
    },
    width = 40,
    zindex = 60,
    prompt = "> ",
    on_submit = function(new_name)
      if new_name and new_name ~= "" and new_name ~= current_name then
        if callback then
          callback(new_name)
        end
      end
    end,
    on_close = function()
      local workspace_window = require "tagonaut.workspace.window"
      local state = workspace_window.get_window_state()
      if state.popup and state.popup.winid and vim.api.nvim_win_is_valid(state.popup.winid) then
        vim.api.nvim_set_current_win(state.popup.winid)
      end
    end,
  }

  input:map("i", "<Esc>", function()
    input:unmount()
  end, { noremap = true })

  input:map("n", "<Esc>", function()
    input:unmount()
  end, { noremap = true })

  input:mount()
end

function M.search_workspaces(popup, callback)
  local editor_width = vim.o.columns
  local search_width = 30

  local input = Input({
    relative = "editor",
    position = {
      row = 1,
      col = editor_width - search_width - 2,
    },
    size = {
      width = search_width,
    },
    border = {
      style = "rounded",
      text = {
        top = " Search ",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Special",
    },
    zindex = 60,
  }, {
    prompt = "🔍 ",
    on_submit = function(value)
      if callback then
        callback(value or "")
      end
    end,
    on_close = function()
      if callback then
        callback ""
      end

      if popup and popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
        vim.api.nvim_set_current_win(popup.winid)
      end
    end,
  })

  input:map("i", "<Esc>", function()
    input:unmount()
  end, { noremap = true })

  input:map("i", "/", function()
    input:unmount()
  end, { noremap = true })

  input:mount()
end

function M.confirm_action(opts)
  local input = create_input_popup {
    title = " " .. opts.title .. " ",
    prompt = opts.message .. " (y/N): ",
    on_submit = function(value)
      if value and value:lower() == "y" then
        if opts.on_confirm then
          opts.on_confirm()
        end
      else
        if opts.on_cancel then
          opts.on_cancel()
        end
      end
    end,
    on_close = function()
      if opts.on_cancel then
        opts.on_cancel()
      end
    end,
  }

  input:mount()
end

function M.delete_workspace(popup, workspace_path, callback)
  if not workspace_path then
    return
  end

  M.confirm_action {
    title = "Delete Workspace",
    message = "Are you sure you want to delete this workspace?",
    on_confirm = function()
      if callback then
        callback(true)
      end
    end,
    on_cancel = function()
      if callback then
        callback(false)
      end

      if popup and popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
        vim.api.nvim_set_current_win(popup.winid)
      end
    end,
  }
end

function M.get_current_workspace_at_cursor(state)
  if not state.workspaces or #state.workspaces == 0 then
    return nil
  end

  return state.workspaces[state.cursor_pos]
end

function M.format_path(path)
  local home = os.getenv "HOME"
  if home then
    path = path:gsub("^" .. vim.pesc(home), "~")
  end
  return path
end

function M.format_timestamp(timestamp)
  if not timestamp or timestamp == 0 then
    return "Never"
  end
  return os.date("%Y-%m-%d %H:%M", timestamp)
end

return M
