local M = {}

local api = vim.api
local state = require "tagonaut.floating.state"
local utils = require "tagonaut.floating.utils"
local config = require("tagonaut.config").options

local function create_legend()
  local legend_items = {
    { key = config.floating_window.close:gsub("<CR>", "Enter"), desc = "Close" },
    { key = config.floating_window.select:gsub("<CR>", "Enter"), desc = "Select" },
    { key = config.floating_window.delete:gsub("<CR>", "Enter"), desc = "Delete" },
    { key = config.floating_window.clear:gsub("<CR>", "Enter"), desc = "Clear" },
    { key = config.floating_window.assign_key:gsub("<CR>", "Enter"), desc = "Assign" },
    { key = config.floating_window.rename:gsub("<CR>", "Enter"), desc = "Rename" },
    { key = "Esc", desc = "Close" },
  }

  local formatted_items = {}
  for _, item in ipairs(legend_items) do
    table.insert(formatted_items, string.format("%s:%s", item.key, item.desc))
  end

  return { "  " .. table.concat(formatted_items, "  |  ") }
end

local function highlight_legend(buffer, legend_line)
  local ns_id = vim.api.nvim_create_namespace "TagonautTagsHighlight"
  local line = vim.api.nvim_buf_get_lines(buffer, legend_line, legend_line + 1, false)[1]
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

    vim.api.nvim_buf_add_highlight(buffer, ns_id, "Special", legend_line, key_start, colon_pos)
    vim.api.nvim_buf_add_highlight(buffer, ns_id, "Comment", legend_line, colon_pos, desc_end)

    current_pos = desc_end + 5
    if current_pos >= #line then
      break
    end
  end
end

local function apply_mappings(buffer)
  local function map(mode, lhs, rhs)
    vim.api.nvim_buf_set_keymap(buffer, mode, lhs, rhs, { noremap = true, silent = true })
  end

  map("n", config.floating_window.close, ':lua require("tagonaut.floating").close()<CR>')
  map("n", config.floating_window.select, ':lua require("tagonaut.floating").select()<CR>')
  map("n", config.floating_window.delete, ':lua require("tagonaut.floating").delete()<CR>')
  map("n", config.floating_window.clear, ':lua require("tagonaut.floating").clear()<CR>')
  map("n", config.floating_window.assign_key, ':lua require("tagonaut.floating").assign_shortcut()<CR>')
  map("n", config.floating_window.rename, ':lua require("tagonaut.floating").rename_tag()<CR>')
  map("n", "<Esc>", ':lua require("tagonaut.floating").close()<CR>')
end

function M.is_window_open()
  local main_window = state.get_main_window()
  return main_window and api.nvim_win_is_valid(main_window)
end

function M.close_windows()
  local preview_window = state.get_preview_window()
  local preview_buffer = state.get_preview_buffer()
  local main_window = state.get_main_window()
  local main_buffer = state.get_main_buffer()
  local legend_window = state.get_legend_window()
  local legend_buffer = state.get_legend_buffer()

  if config.show_legend then
    if legend_window and api.nvim_win_is_valid(legend_window) then
      api.nvim_win_close(legend_window, true)
    end
    if legend_buffer and api.nvim_buf_is_valid(legend_buffer) then
      api.nvim_buf_delete(legend_buffer, { force = true })
    end
  end

  if preview_window and api.nvim_win_is_valid(preview_window) then
    api.nvim_win_close(preview_window, true)
  end
  if preview_buffer and api.nvim_buf_is_valid(preview_buffer) then
    api.nvim_buf_delete(preview_buffer, { force = true })
  end

  if main_window and api.nvim_win_is_valid(main_window) then
    api.nvim_win_close(main_window, true)
  end
  if main_buffer and api.nvim_buf_is_valid(main_buffer) then
    api.nvim_buf_delete(main_buffer, { force = true })
  end

  state.reset()
  vim.cmd "stopinsert"
end

function M.create_preview_window(tag_info)
  if not tag_info then
    return
  end

  local preview_window = state.get_preview_window()
  local preview_buffer = state.get_preview_buffer()

  if not preview_window or not api.nvim_win_is_valid(preview_window) then
    local total_width = math.floor(vim.o.columns * 0.80)
    local list_width = math.floor(vim.o.columns * 0.25)
    local preview_width = math.floor(vim.o.columns * 0.55)
    local legend_height = config.show_legend and 3 or 0
    local height = math.floor(vim.o.lines * 0.8) - legend_height
    local row = math.floor((vim.o.lines - height - legend_height) / 2)
    local start_x = math.floor((vim.o.columns - total_width) / 2)
    local col = start_x + list_width + 2

    preview_buffer = api.nvim_create_buf(false, true)
    api.nvim_set_option_value("modifiable", true, { buf = preview_buffer })
    api.nvim_set_option_value("buftype", "nofile", { buf = preview_buffer })
    api.nvim_set_option_value("swapfile", false, { buf = preview_buffer })
    api.nvim_set_option_value("bufhidden", "hide", { buf = preview_buffer })

    preview_window = api.nvim_open_win(preview_buffer, false, {
      relative = "editor",
      width = preview_width,
      height = height,
      row = row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = " Preview ",
      title_pos = "center",
    })

    apply_mappings(preview_buffer)

    state.set_preview_window(preview_window)
    state.set_preview_buffer(preview_buffer)
    api.nvim_set_option_value("scrolloff", math.floor(height / 3), { win = preview_window })
  end

  if preview_buffer and api.nvim_buf_is_valid(preview_buffer) then
    api.nvim_set_option_value("modifiable", true, { buf = preview_buffer })

    local lines = vim.fn.readfile(tag_info.path)
    api.nvim_buf_set_lines(preview_buffer, 0, -1, false, lines)

    api.nvim_buf_clear_namespace(preview_buffer, -1, 0, -1)

    local filetype = vim.filetype.match { filename = tag_info.path }
    if filetype then
      api.nvim_set_option_value("filetype", filetype, { buf = preview_buffer })
    end

    if tag_info.line then
      local line = tag_info.line - 1
      api.nvim_buf_add_highlight(preview_buffer, -1, "Search", line, 0, -1)
      api.nvim_win_set_cursor(preview_window, { line + 1, 0 })
      api.nvim_win_call(preview_window, function()
        vim.cmd "normal! zt"
      end)
    end

    api.nvim_set_option_value("modifiable", false, { buf = preview_buffer })
  end
end

function M.create_main_window(title)
  local total_width = math.floor(vim.o.columns * 0.80)
  local list_width = math.floor(vim.o.columns * 0.25)
  local legend_height = config.show_legend and 3 or 0
  local main_height = math.floor(vim.o.lines * 0.8) - legend_height
  local row = math.floor((vim.o.lines - main_height - legend_height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)

  local new_main_buffer = api.nvim_create_buf(false, true)
  api.nvim_set_option_value("modifiable", false, { buf = new_main_buffer })
  api.nvim_set_option_value("buftype", "nofile", { buf = new_main_buffer })

  local new_main_window = api.nvim_open_win(new_main_buffer, true, {
    relative = "editor",
    width = list_width,
    height = main_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    zindex = 20,
  })

  api.nvim_set_option_value("cursorline", true, { win = new_main_window })
  api.nvim_set_option_value("cursorlineopt", "line", { win = new_main_window })

  api.nvim_buf_set_keymap(new_main_buffer, "n", "h", "", { noremap = true })
  api.nvim_buf_set_keymap(new_main_buffer, "n", "l", "", { noremap = true })
  apply_mappings(new_main_buffer)

  api.nvim_create_autocmd("CursorMoved", {
    buffer = new_main_buffer,
    callback = function()
      if new_main_window and api.nvim_win_is_valid(new_main_window) then
        local cursor = api.nvim_win_get_cursor(new_main_window)
        local tag_list = state.get_current_tag_list()
        local tag = tag_list[cursor[1]]
        if tag then
          M.create_preview_window(tag.info)
        end
      end
    end,
  })

  api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(new_main_window),
    callback = function()
      vim.schedule(function()
        M.close_windows()
      end)
    end,
    once = true,
  })

  state.set_main_window(new_main_window)
  state.set_main_buffer(new_main_buffer)

  if config.show_legend then
    local legend_width = total_width + 1
    local legend_row = row + main_height + 2

    local new_legend_buffer = api.nvim_create_buf(false, true)
    api.nvim_set_option_value("modifiable", true, { buf = new_legend_buffer })
    api.nvim_set_option_value("buftype", "nofile", { buf = new_legend_buffer })

    local new_legend_window = api.nvim_open_win(new_legend_buffer, false, {
      relative = "editor",
      width = legend_width,
      height = 1,
      row = legend_row,
      col = col,
      style = "minimal",
      border = "rounded",
      title = " Legend ",
      title_pos = "center",
      zindex = 20,
    })

    local legend_lines = create_legend()
    api.nvim_buf_set_lines(new_legend_buffer, 0, -1, false, legend_lines)
    highlight_legend(new_legend_buffer, 0)

    api.nvim_set_option_value("modifiable", false, { buf = new_legend_buffer })

    state.set_legend_window(new_legend_window)
    state.set_legend_buffer(new_legend_buffer)
  end
end

function M.update_main_window()
  local main_buffer = state.get_main_buffer()
  local tag_list = state.get_current_tag_list()

  if not main_buffer or not api.nvim_buf_is_valid(main_buffer) then
    return
  end

  local lines = utils.format_tag_lines(tag_list)

  api.nvim_set_option_value("modifiable", true, { buf = main_buffer })
  api.nvim_buf_set_lines(main_buffer, 0, -1, false, lines)
  utils.apply_highlights(main_buffer, lines)
  api.nvim_set_option_value("modifiable", false, { buf = main_buffer })
end

return M
