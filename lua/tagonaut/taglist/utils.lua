local M = {}
local api = vim.api

M.SORT_MODES = {
  NAME = "name",
  PATH = "path",
  LINE = "line",
  SHORTCUT = "shortcut",
}

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

  table.sort(tag_list, sort_functions[sort_mode or M.SORT_MODES.NAME])

  vim.notify("Sorted tag list: " .. vim.inspect(tag_list))
  return tag_list
end

function M.filter_tags(tags, query)
  if not query or query == "" then
    return tags
  end

  local filtered = {}
  query = query:lower()

  for _, tag in ipairs(tags) do
    local info = M.format_tag_info(tag)
    if M.matches_search(info, query) then
      table.insert(filtered, tag)
    end
  end

  return filtered
end

function M.matches_search(info, query)
  local searchable_fields = {
    info.name,
    info.file,
    info.shortcut,
    tostring(info.line),
    info.full_path,
  }

  for _, field in ipairs(searchable_fields) do
    if field and field:lower():find(query, 1, true) then
      return true
    end
  end

  return false
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

function M.calculate_window_dimensions(options)
  local config = require("tagonaut.config").options.taglist_window
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines

  options = vim.tbl_extend("force", {
    width_ratio = config.width or 0.8,
    height_ratio = config.height or 0.8,
    min_width = config.min_width or 80,
    min_height = config.min_height or 20,
  }, options or {})

  local width = math.floor(screen_width * options.width_ratio)
  local height = math.floor(screen_height * options.height_ratio)

  width = math.max(width, options.min_width)
  height = math.max(height, options.min_height)

  width = math.min(width, screen_width - 4)
  height = math.min(height, screen_height - 4)

  local row = math.floor((screen_height - height) / 2)
  local col = math.floor((screen_width - width) / 2)

  return {
    width = width,
    height = height,
    row = row,
    col = col,
  }
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
