local M = {}
local api = vim.api
local state = require "tagonaut.floating.state"

local COLUMN_WIDTHS = {
  name = 30,
  timestamp = 20,
  tags = 5,
  spacing = 8,
}

function M.generate_legend(config)
  local legend_items = {
    { key = config.workspace_window.select:gsub("<CR>", "Enter"), desc = "Select" },
    { key = config.workspace_window.cycle_sort, desc = "Sort" },
    { key = config.workspace_window.toggle_show_ignored, desc = "ShowIgnored" },
    { key = config.workspace_window.toggle_ignore, desc = "ToggleIgnore" },
    { key = config.workspace_window.rename, desc = "Rename" },
    { key = config.workspace_window.close, desc = "Close" },
  }

  local formatted_items = {}
  for _, item in ipairs(legend_items) do
    table.insert(formatted_items, string.format("%s:%s", item.key, item.desc))
  end

  local legend = "  " .. table.concat(formatted_items, "  |  ")
  return { legend }
end

function M.calculate_dimensions(workspace_count)
  local width = math.floor(vim.o.columns * 0.8)
  local config = require("tagonaut.config").options
  local legend_height = config.show_legend and 2 or 0
  local height = math.min(workspace_count + 2 + legend_height, math.floor(vim.o.lines * 0.8))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local path_width =
    math.min(90, width - COLUMN_WIDTHS.name - COLUMN_WIDTHS.timestamp - COLUMN_WIDTHS.tags - COLUMN_WIDTHS.spacing)

  return {
    width = width,
    height = height,
    row = row,
    col = col,
    path_width = path_width,
    legend_height = legend_height,
  }
end

function M.format_timestamp(timestamp)
  if timestamp == 0 then
    return "Never"
  end
  return os.date("%Y-%m-%d %H:%M", timestamp)
end

function M.format_path(path, max_width)
  local home = os.getenv "HOME"
  if home then
    path = path:gsub("^" .. home:gsub("%-", "%%-"), "~")
  end

  if #path <= max_width then
    return path
  end

  return "..." .. path:sub(-max_width + 3)
end

function M.generate_content(dimensions)
  local lines = {}
  local config = require("tagonaut.config").options

  local header = string.format(
    "%-3s %-" .. COLUMN_WIDTHS.name .. "s %-" .. dimensions.path_width .. "s %-" .. COLUMN_WIDTHS.timestamp .. "s %s",
    "",
    "Name",
    "Path",
    "Last Accessed",
    "Tags"
  )
  table.insert(lines, header)
  table.insert(lines, string.rep("-", dimensions.width))

  local current_workspace = require("tagonaut.api").get_workspace()

  for _, ws in ipairs(state.workspace_list) do
    local prefix = ws.path == current_workspace and "*" or " "
    local formatted_path = M.format_path(ws.path, dimensions.path_width)
    local formatted_name = ws.name or vim.fn.fnamemodify(ws.path, ":t")

    if #formatted_name > COLUMN_WIDTHS.name then
      formatted_name = formatted_name:sub(1, COLUMN_WIDTHS.name - 3) .. "..."
    end

    local line = string.format(
      "%s   %-" .. COLUMN_WIDTHS.name .. "s %-" .. dimensions.path_width .. "s %-" .. COLUMN_WIDTHS.timestamp .. "s %d",
      prefix,
      formatted_name,
      formatted_path,
      M.format_timestamp(ws.last_accessed),
      ws.tag_count
    )
    table.insert(lines, line)
  end

  if config.show_legend then
    table.insert(lines, "")

    local legend = M.generate_legend(config)
    for _, line in ipairs(legend) do
      table.insert(lines, line)
    end
  end

  return lines
end

function M.highlight_current_workspace(buf, current_workspace)
  if #state.workspace_list > 0 then
    local ns_id = api.nvim_create_namespace "TagonautWorkspaceHighlight"
    for i, ws in ipairs(state.workspace_list) do
      if ws.path == current_workspace then
        api.nvim_buf_add_highlight(buf, ns_id, "Special", i + 1, 0, -1)
        break
      end
    end
  end
end

function M.create_cursor_autocmds(buf, win)
  local config = require("tagonaut.config").options
  local legend_height = config.show_legend and 2 or 0

  vim.api.nvim_create_autocmd("BufEnter", {
    buffer = buf,
    callback = function()
      if api.nvim_win_is_valid(win) and api.nvim_buf_line_count(buf) > 2 then
        api.nvim_win_set_cursor(win, { 3, 0 })
      end
    end,
    once = true,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if not api.nvim_win_is_valid(win) then
        return
      end

      local cursor = api.nvim_win_get_cursor(win)
      local line_count = api.nvim_buf_line_count(buf)

      if cursor[1] <= 2 then
        if line_count > 2 then
          api.nvim_win_set_cursor(win, { 3, 0 })
        end
      elseif cursor[1] > line_count - legend_height then
        api.nvim_win_set_cursor(win, { line_count - legend_height, 0 })
      end
    end,
  })
end

function M.create_cleanup_autocmds(buf, win)
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      if api.nvim_win_is_valid(win) then
        api.nvim_win_close(win, true)
        state.set_main_window(nil)
        state.set_main_buffer(nil)
      end
    end,
    once = true,
  })
end

return M
