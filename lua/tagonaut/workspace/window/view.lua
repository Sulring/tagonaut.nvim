local M = {}
local NuiLine = require "nui.line"
local NuiText = require "nui.text"
local config = require("tagonaut.config").options.workspace_window

local LAYOUT = {
  current_width = 2,
  name_width = 30,
  timestamp_width = 19,
  tags_width = 5,
  padding = 1,
}

local function get_window_width(state)
  if state.popup and state.popup.winid and vim.api.nvim_win_is_valid(state.popup.winid) then
    return vim.api.nvim_win_get_width(state.popup.winid)
  end
  return vim.o.columns
end

local function calculate_path_width(total_width, is_minimal)
  if is_minimal then
    return math.floor(total_width * 0.6)
  end
  local used_width = LAYOUT.current_width
    + LAYOUT.name_width
    + LAYOUT.timestamp_width
    + LAYOUT.tags_width
    + (LAYOUT.padding * 4)
  return math.max(20, total_width - used_width)
end

local function create_padded_text(content, width, highlight, align)
  if width <= 0 then
    return NuiText ""
  end

  local str_width = vim.api.nvim_strwidth(content or "")
  local padding = width - str_width
  local result = ""

  if str_width > width then
    local current_width = 0
    for i = 1, #content do
      local char = content:sub(i, i)
      local char_width = vim.api.nvim_strwidth(char)
      if current_width + char_width + 3 > width then
        result = result .. "..."
        break
      end
      result = result .. char
      current_width = current_width + char_width
    end
    result = result .. string.rep(" ", width - vim.api.nvim_strwidth(result))
  else
    if align == "right" then
      result = string.rep(" ", padding) .. (content or "")
    elseif align == "center" then
      local left_pad = math.floor(padding / 2)
      local right_pad = padding - left_pad
      result = string.rep(" ", left_pad) .. (content or "") .. string.rep(" ", right_pad)
    else
      result = (content or "") .. string.rep(" ", padding)
    end
  end

  return NuiText(result, highlight)
end

local function format_timestamp(timestamp)
  if not timestamp or timestamp == 0 then
    return "Never"
  end
  return os.date("%Y-%m-%d %H:%M", timestamp)
end

local function create_header(total_width)
  local line = NuiLine()
  local path_width = calculate_path_width(total_width)

  line:append(NuiText(string.rep(" ", LAYOUT.current_width)))

  line:append(create_padded_text("Name", LAYOUT.name_width, "TagonautHeader"))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))

  line:append(create_padded_text("Path", path_width, "TagonautHeader"))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))

  line:append(create_padded_text("Last Accessed", LAYOUT.timestamp_width, "TagonautHeader"))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))

  line:append(create_padded_text("Tags", LAYOUT.tags_width, "TagonautHeader", "right"))

  return line
end

local function create_separator(total_width)
  local line = NuiLine()
  line:append(NuiText(string.rep("─", total_width), "TagonautSeparator"))
  return line
end

local function create_workspace_line(workspace, is_current, total_width, is_minimal)
  local line = NuiLine()
  local path_width = calculate_path_width(total_width, is_minimal)

  line:append(NuiText(is_current and "* " or "  ", is_current and "TagonautCurrent" or nil))

  local name = workspace.name or vim.fn.fnamemodify(workspace.path, ":t")
  local name_hl = workspace.ignored and "TagonautIgnored" or nil
  local name_width = is_minimal and math.floor(total_width * 0.3) or LAYOUT.name_width
  line:append(create_padded_text(name, name_width, name_hl))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))

  local path_hl = workspace.ignored and "TagonautIgnored" or "TagonautPath"
  line:append(create_padded_text(workspace.path, path_width, path_hl))

  if not is_minimal then
    line:append(NuiText(string.rep(" ", LAYOUT.padding)))
    local time_hl = workspace.ignored and "TagonautIgnored" or "TagonautTimestamp"
    line:append(create_padded_text(format_timestamp(workspace.last_accessed), LAYOUT.timestamp_width, time_hl))
    line:append(NuiText(string.rep(" ", LAYOUT.padding)))
    local tags_hl = workspace.ignored and "TagonautIgnored" or "TagonautTags"
    line:append(create_padded_text(tostring(workspace.tag_count), LAYOUT.tags_width, tags_hl, "right"))
  end

  return line
end

local function create_legend()
  local LEGEND = {
    { key = config.select or "<CR>", desc = "select" },
    { key = config.cycle_sort or "s", desc = "sort" },
    { key = config.toggle_ignore or "d", desc = "toggle ignore" },
    { key = config.toggle_show_ignored or "i", desc = "show/hide ignored" },
    { key = config.rename or "r", desc = "rename" },
    { key = "/", desc = "search" },
    { key = "l", desc = "toggle legend" },
    { key = "m", desc = "toggle minimal" },
    { key = config.close or "q", desc = "quit" },
  }

  local line = NuiLine()
  for i, item in ipairs(LEGEND) do
    if i > 1 then
      line:append(NuiText " │ ")
    end
    line:append(NuiText(item.key, "TagonautKey"))
    line:append(NuiText ": ")
    line:append(NuiText(item.desc))
  end
  return line
end

function M.setup_highlights()
  local highlights = {
    TagonautHeader = { link = "Title" },
    TagonautSeparator = { link = "NonText" },
    TagonautCurrent = { link = "Special" },
    TagonautIgnored = { link = "Comment" },
    TagonautPath = { link = "Directory" },
    TagonautTimestamp = { link = "NonText" },
    TagonautTags = { link = "Number" },
    TagonautKey = { link = "Special" },
  }

  for name, def in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, def)
  end
end

function M.render_content(state)
  if not state.popup or not state.popup.bufnr or not vim.api.nvim_buf_is_valid(state.popup.bufnr) then
    return
  end

  local total_width = get_window_width(state)
  local ns_id = vim.api.nvim_create_namespace "tagonaut_workspace"

  vim.bo[state.popup.bufnr].modifiable = true

  local lines = {}
  local contents = {}

  if not state.minimal then
    local header = create_header(total_width)
    table.insert(lines, header)
    table.insert(contents, header:content())

    local separator = create_separator(total_width)
    table.insert(lines, separator)
    table.insert(contents, separator:content())
  end

  if #state.workspaces == 0 then
    local message = NuiLine()
    message:append(NuiText "No workspaces found")
    table.insert(lines, message)
    table.insert(contents, message:content())
  else
    local current_workspace = require("tagonaut.api").get_workspace()
    for _, ws in ipairs(state.workspaces) do
      local line = create_workspace_line(ws, ws.path == current_workspace, total_width, state.minimal)
      table.insert(lines, line)
      table.insert(contents, line:content())
    end
  end

  if state.show_legend then
    local footer_separator = create_separator(total_width)
    table.insert(lines, footer_separator)
    table.insert(contents, footer_separator:content())

    local legend = create_legend()
    table.insert(lines, legend)
    table.insert(contents, legend:content())
  end

  vim.api.nvim_buf_set_lines(state.popup.bufnr, 0, -1, false, contents)

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(state.popup.bufnr) then
      vim.api.nvim_buf_clear_namespace(state.popup.bufnr, ns_id, 0, -1)

      for i, line in ipairs(lines) do
        pcall(function()
          line:highlight(state.popup.bufnr, ns_id, i)
        end)
      end
    end
  end)

  vim.bo[state.popup.bufnr].modifiable = false
end

function M.get_window_title(state)
  local components = {
    "Workspaces",
    "Sort: " .. state.sort_mode,
  }

  if state.show_ignored then
    table.insert(components, "Showing Ignored")
  end

  if state.search_mode and state.search_query ~= "" then
    table.insert(components, "Search: " .. state.search_query)
  end

  if state.minimal then
    table.insert(components, "Minimal")
  end

  return " " .. table.concat(components, " | ") .. " "
end

function M.matches_search(workspace, query)
  if not query or query == "" then
    return true
  end

  query = query:lower()
  local name = (workspace.name or vim.fn.fnamemodify(workspace.path, ":t")):lower()
  local path = workspace.path:lower()

  local pattern = query:gsub(".", function(c)
    return c .. ".*"
  end)

  return name:match(pattern) or path:match(pattern)
end

return M
