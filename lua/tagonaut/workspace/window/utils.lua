local M = {}

function M.fuzzy_match(str, pattern)
  if not str or not pattern or pattern == "" then
    return true
  end

  str = str:lower()
  pattern = pattern:lower()

  local fuzzy_pattern = pattern:gsub(".", function(c)
    return c:match "[%w_-]" and ("[" .. c:lower() .. c:upper() .. "].*") or vim.pesc(c) .. ".*"
  end)

  return str:match(fuzzy_pattern) ~= nil
end

function M.get_visual_width(str)
  if not str then
    return 0
  end
  return vim.api.nvim_strwidth(str)
end

function M.truncate_string(str, max_width, ellipsis)
  if not str then
    return ""
  end
  if not ellipsis then
    ellipsis = "..."
  end

  local width = M.get_visual_width(str)
  if width <= max_width then
    return str
  end

  local ellipsis_width = M.get_visual_width(ellipsis)
  local target_width = max_width - ellipsis_width

  local result = ""
  local current_width = 0

  for _, grapheme in vim.iter(vim.split(str, "")) do
    local char_width = vim.api.nvim_strwidth(grapheme)

    if current_width + char_width > target_width then
      return result .. ellipsis
    end

    result = result .. grapheme
    current_width = current_width + char_width
  end

  return result .. ellipsis
end

function M.pad_string(str, width, align)
  local str_width = M.get_visual_width(str)
  local padding = width - str_width

  if padding <= 0 then
    return str
  end

  if align == "right" then
    return string.rep(" ", padding) .. str
  elseif align == "center" then
    local left_pad = math.floor(padding / 2)
    local right_pad = padding - left_pad
    return string.rep(" ", left_pad) .. str .. string.rep(" ", right_pad)
  else
    return str .. string.rep(" ", padding)
  end
end

function M.create_highlight_groups()
  local highlights = {
    TagonautHeader = { link = "Special" },
    TagonautSeparator = { link = "NonText" },
    TagonautCurrent = { link = "Special" },
    TagonautIgnored = { link = "Comment" },
    TagonautPath = { link = "Directory" },
    TagonautTimestamp = { link = "NonText" },
    TagonautTags = { link = "Number" },
    TagonautSearch = { link = "Search" },
    TagonautBorder = { link = "FloatBorder" },
    TagonautTitle = { link = "Title" },
  }

  for name, def in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, def)
  end
end

function M.normalize_path(path)
  if not path then
    return nil
  end

  path = vim.fn.expand(path)

  path = path:gsub("/*$", "")

  if not path:match "^/" then
    path = vim.fn.fnamemodify(path, ":p")
  end

  return path
end

function M.calculate_window_dimensions()
  local config = require("tagonaut.config").options.workspace_window

  local screen_width = vim.o.columns
  local screen_height = vim.o.lines

  local width = math.floor(screen_width * (config.width or 0.8))
  local height = math.floor(screen_height * (config.height or 0.8))

  width = math.max(width, config.min_width or 80)
  height = math.max(height, config.min_height or 20)

  width = math.min(width, screen_width - 4)
  height = math.min(height, screen_height - 4)

  return {
    width = width,
    height = height,
    row = math.floor((screen_height - height) / 2),
    col = math.floor((screen_width - width) / 2),
  }
end

function M.format_file_size(size)
  local units = { "B", "KB", "MB", "GB" }
  local unit_index = 1

  while size > 1024 and unit_index < #units do
    size = size / 1024
    unit_index = unit_index + 1
  end

  return string.format("%.1f%s", size, units[unit_index])
end

function M.format_relative_time(timestamp)
  if not timestamp or timestamp == 0 then
    return "never"
  end

  local now = os.time()
  local diff = now - timestamp

  local intervals = {
    { 86400 * 365, "year" },
    { 86400 * 30, "month" },
    { 86400 * 7, "week" },
    { 86400, "day" },
    { 3600, "hour" },
    { 60, "minute" },
    { 1, "second" },
  }

  for _, interval in ipairs(intervals) do
    local time = math.floor(diff / interval[1])
    if time > 0 then
      return string.format("%d %s%s ago", time, interval[2], time == 1 and "" or "s")
    end
  end

  return "just now"
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

function M.is_float_window(winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end

  local config = vim.api.nvim_win_get_config(winid)
  return config.relative ~= ""
end

function M.center_cursor(winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  local line = vim.api.nvim_win_get_cursor(winid)[1]
  vim.api.nvim_win_set_cursor(winid, { line, 0 })
  vim.cmd "normal! zz"
end

return M
