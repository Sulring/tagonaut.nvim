local M = {}

local NuiLine = require "nui.line"
local NuiText = require "nui.text"
local NuiPopup = require "nui.popup"
local config = require("tagonaut.config").options.taglist_window

local LAYOUT = {
  indicator_width = 2,
  shortcut_width = 8,
  name_width = 30,
  file_width = 30,
  line_width = 6,
  padding = 1,
  preview_ratio = 0.6,
}

local function create_padded_text(content, width, highlight, align)
  local str = tostring(content or "")
  local str_width = vim.api.nvim_strwidth(str)
  local padding = width - str_width

  if padding < 0 then
    str = vim.fn.strcharpart(str, 0, width - 1) .. "…"
    padding = 0
  end

  local result = align == "right" and string.rep(" ", padding) .. str or str .. string.rep(" ", padding)

  return NuiText(result, highlight)
end

local function create_header_line()
  local line = NuiLine()
  line:append(create_padded_text("", LAYOUT.indicator_width))
  line:append(create_padded_text("Key", LAYOUT.shortcut_width, "TagonautHeader"))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))
  line:append(create_padded_text("Name", LAYOUT.name_width, "TagonautHeader"))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))
  line:append(create_padded_text("File", LAYOUT.file_width, "TagonautHeader"))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))
  line:append(create_padded_text("Line", LAYOUT.line_width, "TagonautHeader", "right"))
  return line
end

local function create_separator(width)
  local line = NuiLine()
  line:append(NuiText(string.rep("─", width), "NonText"))
  return line
end

local function create_tag_line(tag, is_current)
  local line = NuiLine()
  line:append(NuiText(is_current and "*" or " ", is_current and "TagonautCurrent" or nil))
  line:append(create_padded_text(tag.info.shortcut or "", LAYOUT.shortcut_width, "TagonautShortcut"))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))
  line:append(create_padded_text(tag.info.name, LAYOUT.name_width, "TagonautTagName"))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))
  line:append(create_padded_text(vim.fn.fnamemodify(tag.info.path, ":t"), LAYOUT.file_width, "TagonautFile"))
  line:append(NuiText(string.rep(" ", LAYOUT.padding)))
  line:append(create_padded_text(tostring(tag.info.line), LAYOUT.line_width, "TagonautLine", "right"))
  return line
end

local function create_legend()
  local keys = {
    { key = config.select or "<CR>", desc = "select" },
    { key = config.delete or "d", desc = "delete" },
    { key = config.assign_key or "a", desc = "assign key" },
    { key = config.rename or "r", desc = "rename" },
    { key = "/", desc = "search" },
    { key = config.close or "q", desc = "close" },
  }

  local line = NuiLine()
  for i, item in ipairs(keys) do
    if i > 1 then
      line:append(NuiText(" | ", "NonText"))
    end
    line:append(NuiText(item.key, "Special"))
    line:append(NuiText(": ", "NonText"))
    line:append(NuiText(item.desc, "Normal"))
  end

  return line
end

function M.create_main_popup()
  local dims = {
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    row = math.floor((vim.o.lines - math.floor(vim.o.lines * 0.8)) / 2),
    col = math.floor((vim.o.columns - math.floor(vim.o.columns * 0.8)) / 2),
  }

  return NuiPopup {
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = " Tags ",
        top_align = "center",
      },
    },
    position = {
      row = dims.row,
      col = dims.col,
    },
    size = {
      width = math.floor(dims.width * (1 - LAYOUT.preview_ratio)),
      height = dims.height,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
    win_options = {
      cursorline = true,
      wrap = false,
      signcolumn = "no",
    },
  }
end

function M.create_preview_popup(main_popup)
  local dims = {
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    row = math.floor((vim.o.lines - math.floor(vim.o.lines * 0.8)) / 2),
    col = math.floor((vim.o.columns - math.floor(vim.o.columns * 0.8)) / 2),
  }

  return NuiPopup {
    enter = false,
    focusable = false,
    border = {
      style = "rounded",
      text = {
        top = " Preview ",
        top_align = "center",
      },
    },
    position = {
      row = dims.row,
      col = dims.col + math.floor(dims.width * (1 - LAYOUT.preview_ratio)) + 2,
    },
    size = {
      width = math.floor(dims.width * LAYOUT.preview_ratio) - 3,
      height = dims.height,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
    win_options = {
      wrap = false,
      cursorline = true,
      signcolumn = "no",
    },
  }
end

function M.render_content(popup, state)
  if not popup or not popup.bufnr or not vim.api.nvim_buf_is_valid(popup.bufnr) then
    return
  end

  vim.bo[popup.bufnr].modifiable = true

  local lines = {}
  local contents = {}
  local highlight_lines = {}

  local header = create_header_line()
  table.insert(lines, header)
  table.insert(contents, header:content())
  table.insert(highlight_lines, header)

  local separator = create_separator(popup.win_config.width)
  table.insert(lines, separator)
  table.insert(contents, separator:content())

  local tag_list = state.get_current_tag_list()
  local cursor_pos = state.get_cursor_position()

  if #tag_list == 0 then
    local empty = NuiLine()
    empty:append(NuiText "No tags found")
    table.insert(lines, empty)
    table.insert(contents, empty:content())
    table.insert(highlight_lines, empty)
  else
    for i, tag in ipairs(tag_list) do
      local line = create_tag_line(tag, i == cursor_pos)
      table.insert(lines, line)
      table.insert(contents, line:content())
      table.insert(highlight_lines, line)
    end
  end

  local footer_separator = create_separator(popup.win_config.width)
  table.insert(lines, footer_separator)
  table.insert(contents, footer_separator:content())

  local legend = create_legend()
  table.insert(lines, legend)
  table.insert(contents, legend:content())
  table.insert(highlight_lines, legend)

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, contents)

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(popup.bufnr) then
      local ns_id = vim.api.nvim_create_namespace "tagonaut_taglist"
      vim.api.nvim_buf_clear_namespace(popup.bufnr, ns_id, 0, -1)

      local highlight_offset = 0
      for i, line in ipairs(highlight_lines) do
        if line.highlight then
          if i == 1 then
            highlight_offset = 0
          elseif i == 2 then
            highlight_offset = 2
          elseif i > #tag_list + 1 then
            highlight_offset = 3
          end

          pcall(function()
            line:highlight(popup.bufnr, ns_id, i + highlight_offset - 1)
          end)
        end
      end
    end
  end)

  vim.bo[popup.bufnr].modifiable = false
end

function M.update_preview(preview_popup, tag_info)
  if not preview_popup or not preview_popup.bufnr or not vim.api.nvim_buf_is_valid(preview_popup.bufnr) then
    return
  end

  vim.bo[preview_popup.bufnr].modifiable = true

  if vim.fn.filereadable(tag_info.path) == 1 then
    local lines = vim.fn.readfile(tag_info.path)
    vim.api.nvim_buf_set_lines(preview_popup.bufnr, 0, -1, false, lines)

    local filetype = vim.filetype.match { filename = tag_info.path }
    if filetype then
      vim.bo[preview_popup.bufnr].filetype = filetype
    end

    local ns_id = vim.api.nvim_create_namespace "tagonaut_preview"
    vim.api.nvim_buf_clear_namespace(preview_popup.bufnr, ns_id, 0, -1)
    vim.api.nvim_buf_add_highlight(preview_popup.bufnr, ns_id, "Search", tag_info.line - 1, 0, -1)

    vim.api.nvim_win_set_cursor(preview_popup.winid, { tag_info.line, 0 })
    vim.api.nvim_win_call(preview_popup.winid, function()
      vim.cmd "normal! zz"
    end)
  else
    vim.api.nvim_buf_set_lines(preview_popup.bufnr, 0, -1, false, { "File not found: " .. tag_info.path })
  end

  vim.bo[preview_popup.bufnr].modifiable = false
end

function M.setup_highlights()
  local highlights = {
    TagonautHeader = { link = "Title" },
    TagonautSeparator = { link = "NonText" },
    TagonautCurrent = { link = "Special" },
    TagonautKey = { link = "Special" },
    TagonautLegend = { link = "Normal" },
    TagonautTagName = { link = "Identifier" },
    TagonautFile = { link = "Directory" },
    TagonautLine = { link = "Number" },
    TagonautShortcut = { link = "Special" },
  }

  for name, def in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, def)
  end
end

return M
