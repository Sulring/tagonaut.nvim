local M = {}
local api = vim.api
local state = require "tagonaut.floating.state"
local utils = require "tagonaut.workspace.window.utils"

local function highlight_legend(buf, ns_id, legend_line_num)
  local line = api.nvim_buf_get_lines(buf, legend_line_num - 1, legend_line_num, false)[1]
  local current_pos = 2

  while true do
    local key_start = current_pos
    local colon_pos = line:find(":", key_start)
    if not colon_pos then
      break
    end

    local desc_end = line:find("  |  ", colon_pos + 1) or #line + 1
    if desc_end > colon_pos then
      desc_end = desc_end - 1
    end

    api.nvim_buf_add_highlight(buf, ns_id, "Special", legend_line_num - 1, key_start, colon_pos)
    api.nvim_buf_add_highlight(buf, ns_id, "Comment", legend_line_num - 1, colon_pos, desc_end)

    current_pos = desc_end + 5
    if current_pos >= #line then
      break
    end
  end
end

function M.create_window(window_state)
  local buf = api.nvim_create_buf(false, true)
  local dimensions = utils.calculate_dimensions(#state.workspace_list)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = dimensions.width,
    height = dimensions.height,
    row = dimensions.row,
    col = dimensions.col,
    style = "minimal",
    border = "rounded",
    title = string.format(
      " Workspaces (%s) %s ",
      window_state.sort_mode,
      window_state.show_ignored and "[Showing Ignored]" or ""
    ),
    title_pos = "center",
  })

  M.setup_window_content(buf, win, dimensions)

  M.setup_window_options(buf, win)
  M.setup_keymaps(buf)
  M.setup_autocmds(buf, win)

  state.set_main_window(win)
  state.set_main_buffer(buf)
end

function M.setup_window_content(buf, win, dimensions)
  local lines = utils.generate_content(dimensions)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local current_workspace = require("tagonaut.api").get_workspace()
  utils.highlight_current_workspace(buf, current_workspace)

  local ns_id = api.nvim_create_namespace "TagonautWorkspaceHighlight"
  highlight_legend(buf, ns_id, #lines)
end

function M.setup_window_options(buf, win)
  local window_options = {
    cursorline = true,
    number = false,
    relativenumber = false,
    wrap = false,
  }

  local buffer_options = {
    modifiable = false,
    bufhidden = "wipe",
    buftype = "nofile",
    swapfile = false,
    filetype = "tagonaut-workspaces",
  }

  for option, value in pairs(window_options) do
    vim.api.nvim_set_option_value(option, value, { win = win })
  end

  for option, value in pairs(buffer_options) do
    vim.api.nvim_set_option_value(option, value, { buf = buf })
  end
end

function M.setup_keymaps(buf)
  local config = require("tagonaut.config").options
  local opts = { noremap = true, silent = true, nowait = true }

  local keymaps = {
    [config.workspace_window.close] = "<cmd>close<CR>",
    ["<Esc>"] = "<cmd>close<CR>",
    [config.workspace_window.select] = [[<cmd>lua require('tagonaut.workspace.window').select_workspace()<CR>]],
    [config.workspace_window.cycle_sort] = [[<cmd>lua require('tagonaut.workspace.window').cycle_sort_mode()<CR>]],
    [config.workspace_window.toggle_show_ignored] = [[<cmd>lua require('tagonaut.workspace.window').toggle_show_ignored()<CR>]],
    [config.workspace_window.toggle_ignore] = [[<cmd>lua require('tagonaut.workspace.window').toggle_ignore_current()<CR>]],
    [config.workspace_window.rename] = [[<cmd>lua require('tagonaut.workspace.window').rename_current()<CR>]],
  }

  for key, mapping in pairs(keymaps) do
    api.nvim_buf_set_keymap(buf, "n", key, mapping, opts)
  end
end

function M.setup_autocmds(buf, win)
  utils.create_cursor_autocmds(buf, win)
  utils.create_cleanup_autocmds(buf, win)
end

function M.update_window_content(buf, win, dimensions, window_state)
  local lines = utils.generate_content(dimensions)
  local current_workspace = require("tagonaut.api").get_workspace()
  local config = require("tagonaut.config").options
  local title = string.format(
    " Workspaces (%s) %s ",
    window_state.sort_mode,
    window_state.show_ignored and "[Showing Ignored]" or ""
  )

  vim.api.nvim_buf_call(buf, function()
    api.nvim_set_option_value("modifiable", true, { buf = buf })

    api.nvim_win_set_config(win, {
      title = title,
      title_pos = "center",
    })
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local ns_id = api.nvim_create_namespace "TagonautWorkspaceHighlight"
    api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

    utils.highlight_current_workspace(buf, current_workspace)

    if config.show_legend and #lines > 0 then
      highlight_legend(buf, ns_id, #lines)
    end

    api.nvim_set_option_value("modifiable", false, { buf = buf })
  end)
end

function M.close_window()
  local win = state.get_main_window()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    state.set_main_window(nil)
    state.set_main_buffer(nil)
  end
end

function M.get_window_state()
  local win = state.get_main_window()
  return win and vim.api.nvim_win_is_valid(win)
end

return M
