local M = {}

local NuiLine = require "nui.line"
local NuiText = require "nui.text"
local NuiPopup = require "nui.popup"
local utils = require "tagonaut.taglist.utils"
local state = require "tagonaut.taglist.state"

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
  local layout = utils.get_layout(state.get_minimal_mode())
  local line = NuiLine()
  line:append(NuiText(string.rep(" ", layout.indicator_width)))
  line:append(create_padded_text("Key", layout.shortcut_width, "TagonautHeader"))
  line:append(NuiText(string.rep(" ", layout.padding)))
  line:append(create_padded_text("Name", layout.name_width, "TagonautHeader"))
  line:append(NuiText(string.rep(" ", layout.padding)))
  line:append(create_padded_text("File", layout.file_width, "TagonautHeader"))
  line:append(NuiText(string.rep(" ", layout.padding)))
  line:append(create_padded_text("Line", layout.line_width, "TagonautHeader", "right"))
  return line, "TagonautHeader"
end

local function create_separator(width)
  return NuiLine():append(NuiText(string.rep("─", width), "TagonautSeparator"))
end

local function create_tag_line(tag, _)
  local layout = utils.get_layout(state.get_minimal_mode())
  local line = NuiLine()
  line:append(NuiText(" ", "TagonautPadding"))
  line:append(create_padded_text(tag.info.shortcut or "", layout.shortcut_width, "TagonautShortcut"))
  line:append(NuiText(string.rep(" ", layout.padding)))

  if state.get_minimal_mode() then
    local name_text = tag.info.name
    local file_text = vim.fn.fnamemodify(tag.info.path, ":t")
    local line_text = tostring(tag.info.line)
    local display_text = string.format("%s (%s)", name_text, file_text)

    line:append(create_padded_text(display_text, layout.name_width - #line_text - 1, "TagonautTagName"))
    line:append(create_padded_text(":" .. line_text, #line_text + 1, "TagonautLine"))
  else
    line:append(create_padded_text(tag.info.name, layout.name_width, "TagonautTagName"))
    line:append(NuiText(string.rep(" ", layout.padding)))
    line:append(create_padded_text(vim.fn.fnamemodify(tag.info.path, ":t"), layout.file_width, "TagonautFile"))
    line:append(NuiText(string.rep(" ", layout.padding)))
    line:append(create_padded_text(tostring(tag.info.line), layout.line_width, "TagonautLine", "right"))
  end

  return line
end

local function create_legend()
  local config = require("tagonaut.config").options.taglist_window
  local line = NuiLine()
  local keys = {
    { key = config.select, desc = "select" },
    { key = config.delete, desc = "delete" },
    { key = config.assign_key, desc = "assign key" },
    { key = config.rename, desc = "rename" },
    { key = config.close, desc = "close" },
  }

  for i, item in ipairs(keys) do
    if i > 1 then
      line:append(NuiText(" | ", "NonText"))
    end
    line:append(NuiText(utils.format_key_display(item.key), "Special"))
    line:append(NuiText(": ", "NonText"))
    line:append(NuiText(item.desc, "Comment"))
  end
  return line
end

function M.create_main_popup()
  local dimensions = utils.calculate_window_dimensions(state)

  local popup = NuiPopup {
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = state.get_minimal_mode() and "" or " Tags ",
        top_align = "center",
      },
    },
    position = {
      row = dimensions.row,
      col = dimensions.col,
    },
    size = {
      width = dimensions.width,
      height = dimensions.height,
    },
    win_options = {
      cursorline = true,
      wrap = false,
      signcolumn = "no",
      scrolloff = 1,
    },
  }

  vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
    buffer = popup.bufnr,
    callback = function()
      require("tagonaut.taglist").close()
      return true
    end,
  })

  return popup
end

function M.create_preview_popup()
  if state.get_minimal_mode() then
    return nil
  end

  local dimensions = utils.calculate_window_dimensions(state)
  local main_width = dimensions.width
  local preview_width = dimensions.total_width - main_width - 3

  return NuiPopup {
    enter = false,
    focusable = false,
    relative = "editor",
    border = {
      style = "rounded",
      text = {
        top = " Preview ",
        top_align = "center",
      },
    },
    position = {
      row = dimensions.row,
      col = dimensions.start_col + main_width + 2,
    },
    size = {
      width = preview_width,
      height = dimensions.height,
    },
    win_options = {
      wrap = false,
      cursorline = true,
      signcolumn = "no",
    },
  }
end

function M.render_content(popup)
  if not popup or not popup.bufnr or not vim.api.nvim_buf_is_valid(popup.bufnr) then
    return
  end

  vim.bo[popup.bufnr].modifiable = true

  local lines = {}
  local highlights = {}

  if not state.get_minimal_mode() then
    local header_line, header_hl = create_header_line()
    local separator_line = create_separator(popup.win_config.width)
    table.insert(lines, header_line)
    table.insert(lines, separator_line)
    table.insert(highlights, { line = 0, hl = "TagonautHeader" })
    table.insert(highlights, { line = 1, hl = "TagonautSeparator" })
  end

  local tag_list = state.get_current_tag_list()
  local cursor_pos = state.get_cursor_position()
  local start_line = state.get_minimal_mode() and 0 or 2

  if #tag_list == 0 then
    local empty = NuiLine()
    empty:append(NuiText("No tags found", "Comment"))
    table.insert(lines, empty)
  else
    for i, tag in ipairs(tag_list) do
      local line = create_tag_line(tag, i == cursor_pos)
      table.insert(lines, line)
      table.insert(highlights, { line = i + start_line, tag = true, content = line })
    end
  end

  if state.get_show_legend() and not state.get_minimal_mode() then
    local legend_separator = create_separator(popup.win_config.width)
    local legend_line = create_legend()

    table.insert(lines, legend_separator)
    table.insert(lines, legend_line)

    table.insert(highlights, {
      line = #lines - 2,
      hl = "TagonautSeparator",
    })
    table.insert(highlights, {
      line = #lines,
      content = legend_line,
    })
  end

  local contents = vim.tbl_map(function(line)
    return line:content()
  end, lines)
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, contents)

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(popup.bufnr) then
      local ns_id = vim.api.nvim_create_namespace "tagonaut_taglist"
      vim.api.nvim_buf_clear_namespace(popup.bufnr, ns_id, 0, -1)

      for _, hl in ipairs(highlights) do
        if hl.content then
          pcall(hl.content.highlight, hl.content, popup.bufnr, ns_id, hl.line)
        elseif hl.hl then
          pcall(vim.api.nvim_buf_add_highlight, popup.bufnr, ns_id, hl.hl, hl.line, 0, -1)
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
    TagonautCurrent = { link = "CursorLine" },
    TagonautKey = { link = "Special" },
    TagonautDesc = { link = "Comment" },
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
