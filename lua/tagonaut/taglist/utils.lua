local M = {}
local api = vim.api

M.SORT_MODES = {
  NAME = "name",
  PATH = "path",
  LINE = "line",
  SHORTCUT = "shortcut",
}

M.MINIMAL_LAYOUT = {
  indicator_width = 2,
  shortcut_width = 4,
  name_width = 50,
  padding = 1,
}

M.FULL_LAYOUT = {
  indicator_width = 2,
  shortcut_width = 8,
  name_width = 30,
  file_width = 30,
  line_width = 6,
  padding = 1,
  preview_ratio = 0.6,
}

function M.get_layout(minimal)
  return minimal and M.MINIMAL_LAYOUT or M.FULL_LAYOUT
end

function M.get_base_coordinates()
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  local total_width = math.floor(screen_width * 0.8)
  local col_start = math.floor((screen_width - total_width) / 2)
  local height = math.floor(screen_height * 0.8)
  local row_start = math.floor((screen_height - height) / 2)

  return {
    total_width = total_width,
    height = height,
    col_start = col_start,
    row_start = row_start,
  }
end

function M.calculate_content_width(minimal)
  if minimal then
    local total_width = M.MINIMAL_LAYOUT.indicator_width
      + M.MINIMAL_LAYOUT.shortcut_width
      + M.MINIMAL_LAYOUT.name_width
      + (M.MINIMAL_LAYOUT.padding * 2)
    return total_width
  end

  return M.FULL_LAYOUT.indicator_width
    + M.FULL_LAYOUT.shortcut_width
    + M.FULL_LAYOUT.name_width
    + M.FULL_LAYOUT.file_width
    + M.FULL_LAYOUT.line_width
    + (M.FULL_LAYOUT.padding * 4)
end

function M.calculate_window_dimensions(state)
  local minimal = state.get_minimal_mode()
  local tag_count = #state.get_current_tag_list()

  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  local total_width = math.floor(screen_width * 0.8)
  local total_height = math.floor(screen_height * 0.8)
  local start_row = math.floor((screen_height - total_height) / 2)
  local start_col = math.floor((screen_width - total_width) / 2)

  if minimal then
    local content_width = M.calculate_content_width(true)
    local width = math.min(content_width + 2, screen_width - 4)
    local height = math.min(tag_count, screen_height - 4)

    return {
      width = width,
      height = height,
      row = math.floor((screen_height - height) / 2),
      col = math.floor((screen_width - width) / 2),
      start_col = start_col,
      start_row = start_row,
      total_width = total_width,
    }
  else
    local main_width = math.floor(total_width * 0.4)

    return {
      width = main_width,
      height = total_height,
      row = start_row,
      col = start_col,
      start_col = start_col,
      start_row = start_row,
      total_width = total_width,
    }
  end
end

function M.format_tag_info(tag)
  if not tag or not tag.info then
    return {
      name = "Unknown",
      file = "Unknown",
      line = 0,
      shortcut = "",
    }
  end

  return {
    name = tag.info.name or "Unnamed",
    file = vim.fn.fnamemodify(tag.info.path, ":t"),
    line = tag.info.line or 0,
    shortcut = tag.info.shortcut or "",
    full_path = tag.info.path,
  }
end

function M.get_sorted_tags(tags)
  local tag_list = {}
  for id, info in pairs(tags) do
    table.insert(tag_list, {
      id = id,
      info = {
        name = info.name,
        path = info.path,
        line = tonumber(info.line),
        shortcut = info.shortcut,
      },
    })
  end

  local sort_functions = {
    [M.SORT_MODES.NAME] = function(a, b)
      return (a.info.name or ""):lower() < (b.info.name or ""):lower()
    end,
    [M.SORT_MODES.PATH] = function(a, b)
      return (a.info.path or "") < (b.info.path or "")
    end,
    [M.SORT_MODES.LINE] = function(a, b)
      return (a.info.line or 0) < (b.info.line or 0)
    end,
    [M.SORT_MODES.SHORTCUT] = function(a, b)
      return (a.info.shortcut or "") < (b.info.shortcut or "")
    end,
  }

  table.sort(tag_list, sort_functions[M.SORT_MODES.NAME])
  return tag_list
end

function M.format_key_display(key)
  if not key then
    return ""
  end

  local replacements = {
    ["<CR>"] = "Enter",
    ["<C%-(%w)>"] = "Ctrl+%1",
    ["<S%-(%w)>"] = "Shift+%1",
    ["<A%-(%w)>"] = "Alt+%1",
    ["<M%-(%w)>"] = "Meta+%1",
    ["<leader>"] = "Leader",
    ["<Esc>"] = "Esc",
  }

  local display_key = key
  for pattern, replace in pairs(replacements) do
    display_key = display_key:gsub(pattern, replace)
  end
  return display_key
end

function M.format_path(path)
  if not path then
    return ""
  end

  local home = os.getenv "HOME"
  if home then
    path = path:gsub("^" .. vim.pesc(home), "~")
  end
  return path
end

function M.debounce(fn, ms)
  local timer = vim.loop.new_timer()
  local running = false

  return function(...)
    local args = { ... }
    if running then
      timer:stop()
    end

    running = true
    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        running = false
        fn(unpack(args))
      end)
    )
  end
end

function M.create_namespace()
  return api.nvim_create_namespace "tagonaut_taglist"
end

function M.set_buffer_options(bufnr, options)
  for option, value in pairs(options) do
    vim.bo[bufnr][option] = value
  end
end

function M.set_window_options(winid, options)
  for option, value in pairs(options) do
    vim.wo[winid][option] = value
  end
end

function M.validate_tag(tag)
  if not tag or not tag.info then
    return false
  end

  local required_fields = { "name", "path", "line" }
  for _, field in ipairs(required_fields) do
    if not tag.info[field] then
      return false
    end
  end

  return true
end

return M
