local M = {}
local api = vim.api
local config = require("tagonaut.config").options
local tagonaut_api = require "tagonaut.api"
local messages = require "tagonaut.messages"
local utils = require "tagonaut.utils"
local symbols = require "tagonaut.symbols"

local main_window
local main_buffer
local preview_window
local preview_buffer
local deleted_tags = {}

local function close_windows()
  -- Store current success state
  local closed = false

  -- Try to close preview window and buffer if they exist
  if preview_window and api.nvim_win_is_valid(preview_window) then
    pcall(api.nvim_win_close, preview_window, true)
    closed = true
  end
  if preview_buffer and api.nvim_buf_is_valid(preview_buffer) then
    pcall(api.nvim_buf_delete, preview_buffer, { force = true })
    closed = true
  end

  -- Try to close main window and buffer if they exist
  if main_window and api.nvim_win_is_valid(main_window) then
    pcall(api.nvim_win_close, main_window, true)
    closed = true
  end
  if main_buffer and api.nvim_buf_is_valid(main_buffer) then
    pcall(api.nvim_buf_delete, main_buffer, { force = true })
    closed = true
  end

  -- Clean up variables regardless of whether windows existed
  preview_window = nil
  preview_buffer = nil
  main_window = nil
  main_buffer = nil
  deleted_tags = {}

  -- If nothing was closed but the function was called, return to normal mode
  if not closed then
    vim.cmd "stopinsert"
    vim.cmd "normal! <Esc>"
  end
end

local function create_preview_window(tag_info)
  if not tag_info then
    return
  end

  if preview_window and api.nvim_win_is_valid(preview_window) then
    pcall(api.nvim_win_close, preview_window, true)
  end
  if preview_buffer and api.nvim_buf_is_valid(preview_buffer) then
    pcall(api.nvim_buf_delete, preview_buffer, { force = true })
  end

  local total_width = math.floor(vim.o.columns * 0.80)
  local list_width = math.floor(vim.o.columns * 0.25)
  local preview_width = math.floor(vim.o.columns * 0.55)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local start_x = math.floor((vim.o.columns - total_width) / 2)
  local col = start_x + list_width + 2

  preview_buffer = api.nvim_create_buf(false, true)
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

  local lines = vim.fn.readfile(tag_info.path)
  api.nvim_buf_set_lines(preview_buffer, 0, -1, false, lines)

  local filetype = vim.filetype.match { filename = tag_info.path }
  if filetype then
    vim.api.nvim_set_option_value("filetype", filetype, { buf = preview_buffer })
  end

  if tag_info.line then
    local line = tag_info.line - 1
    api.nvim_buf_add_highlight(preview_buffer, -1, "Search", line, 0, -1)
    api.nvim_win_set_cursor(preview_window, { line + 1, 0 })
    vim.api.nvim_win_set_option(preview_window, "scrolloff", math.floor(height / 3))
    api.nvim_win_call(preview_window, function()
      vim.cmd "normal! zt"
    end)
  end
end

local function update_display()
  if main_buffer and api.nvim_buf_is_valid(main_buffer) then
    local cursor_pos = api.nvim_win_get_cursor(main_window)
    M.display_tags(M.tag_list, M.title, M.include_global, cursor_pos[1])
  end
end

local function create_main_window(title)
  local width = math.floor(vim.o.columns * 0.25)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local total_width = math.floor(vim.o.columns * 0.80)
  local center = math.floor(vim.o.columns / 2)
  local col = center - math.floor(total_width / 2)

  main_buffer = api.nvim_create_buf(false, true)
  main_window = api.nvim_open_win(main_buffer, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("cursorline", true, { win = main_window })

  local function map(mode, lhs, rhs)
    vim.api.nvim_buf_set_keymap(main_buffer, mode, lhs, rhs, { noremap = true, silent = true })
  end

  map("n", config.floating_window.close, ':lua require("tagonaut.floating").close()<CR>')
  map("n", config.floating_window.select, ':lua require("tagonaut.floating").select()<CR>')
  map("n", config.floating_window.delete, ':lua require("tagonaut.floating").delete()<CR>')
  map("n", config.floating_window.clear, ':lua require("tagonaut.floating").clear()<CR>')
  map("n", config.floating_window.assign_key, ':lua require("tagonaut.floating").toggle_key_assignment()<CR>')
  map("n", config.floating_window.clear_all_keys, ':lua require("tagonaut.floating").clear_all_keys()<CR>')
  map("n", config.floating_window.rename, ':lua require("tagonaut.floating").rename_tag()<CR>')
  map("n", "<Esc>", ':lua require("tagonaut.floating").close()<CR>')

  -- Create autocmds
  local group = api.nvim_create_augroup("TagonautFloat", { clear = true })

  api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = main_buffer,
    callback = function()
      if main_window and api.nvim_win_is_valid(main_window) then
        local cursor = api.nvim_win_get_cursor(main_window)
        local selected_index = cursor[1]
        if selected_index > 0 and selected_index <= #M.tag_list then
          local selection = M.tag_list[selected_index]
          create_preview_window(selection)
        end
      end
    end,
  })

  api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(main_window),
    callback = function()
      close_windows()
    end,
    once = true,
  })
end

function M.display_tags(tag_list, title, include_global, cursor_pos)
  if main_window and api.nvim_win_is_valid(main_window) then
    api.nvim_win_close(main_window, true)
  end
  if main_buffer and api.nvim_buf_is_valid(main_buffer) then
    api.nvim_buf_delete(main_buffer, { force = true })
  end

  create_main_window(title)

  local icons = {
    local_tag = "󰆧",
    global_tag = "󰊤",
  }

  local max_shortcut_len = 1
  for key, _ in pairs(tagonaut_api.keyed_tags) do
    max_shortcut_len = math.max(max_shortcut_len, vim.fn.strchars(key))
  end

  local max_tag_len = 0
  for _, tag in ipairs(tag_list) do
    max_tag_len = math.max(max_tag_len, vim.fn.strchars(tag.tag))
  end

  local lines = {}
  for _, tag in ipairs(tag_list) do
    local shortcut = "―"
    for key, t in pairs(tagonaut_api.keyed_tags) do
      if t == tag.tag then
        shortcut = key
        break
      end
    end

    local tag_type_icon = tag.type == "global" and icons.global_tag or icons.local_tag
    local shortcut_padding = string.rep(" ", max_shortcut_len - vim.fn.strchars(shortcut))
    local formatted_shortcut = shortcut .. shortcut_padding
    local tag_padding = string.rep(" ", max_tag_len - vim.fn.strchars(tag.tag))
    local formatted_tag = tag.tag .. tag_padding

    local line = string.format("%s [%s] %s", tag_type_icon, formatted_shortcut, formatted_tag)
    table.insert(lines, line)
  end

  api.nvim_buf_set_lines(main_buffer, 0, -1, false, lines)

  M.tag_list = tag_list
  M.include_global = include_global
  M.title = title

  if cursor_pos then
    api.nvim_win_set_cursor(main_window, { cursor_pos, 0 })
  end

  if #tag_list > 0 then
    local preview_index = cursor_pos or 1
    create_preview_window(tag_list[preview_index])
  end
end

function M.close()
  close_windows()
end

function M.select()
  if not (main_window and api.nvim_win_is_valid(main_window)) then
    return
  end

  local cursor = api.nvim_win_get_cursor(main_window)
  local selected_index = cursor[1]

  if selected_index > 0 and selected_index <= #M.tag_list then
    local selection = M.tag_list[selected_index]
    if not deleted_tags[selection.tag] then
      local selected_tag = selection.tag
      local is_global = selection.type == "global"

      close_windows()

      local success, msg = tagonaut_api.jump_to_tag(selected_tag, is_global, symbols)
      if not success then
        print("Failed to jump to tag: " .. msg)
      end
    else
      print "Cannot select a deleted tag"
    end
  end
end

function M.delete()
  if not (main_window and api.nvim_win_is_valid(main_window)) then
    return
  end

  local cursor = api.nvim_win_get_cursor(main_window)
  local selected_index = cursor[1]

  if selected_index > 0 and selected_index <= #M.tag_list then
    local selection = M.tag_list[selected_index]
    if deleted_tags[selection.tag] then
      local success, msg = tagonaut_api.restore_deleted_tag(deleted_tags[selection.tag])
      if success then
        print(msg)
        deleted_tags[selection.tag] = nil
      end
    else
      local success, msg = tagonaut_api.delete_tag(selection.tag, selection.type == "global")
      if success then
        print(msg)
        deleted_tags[selection.tag] = #tagonaut_api.temp_deleted_tags
      end
    end
    M.display_tags(M.tag_list, M.title, M.include_global)
  end
end

function M.clear()
  vim.ui.input(
    { prompt = M.include_global and messages.confirm_clear_all_tags or messages.confirm_clear_local_tags },
    function(input)
      if input and input:lower() == "y" then
        local success, msg = tagonaut_api.clear_all_tags(M.include_global)
        if success then
          print(msg)
          close_windows()
        end
      else
        print(messages.operation_cancelled)
      end
    end
  )
end

function M.toggle_key_assignment()
  if not (main_window and api.nvim_win_is_valid(main_window)) then
    return
  end

  local cursor = api.nvim_win_get_cursor(main_window)
  local selected_index = cursor[1]

  if selected_index > 0 and selected_index <= #M.tag_list then
    local selection = M.tag_list[selected_index]
    local existing_key = nil
    for key, tag in pairs(tagonaut_api.keyed_tags) do
      if tag == selection.tag then
        existing_key = key
        break
      end
    end

    if existing_key then
      local success, msg = tagonaut_api.remove_key_from_tag(existing_key)
      if success then
        print(msg)
        update_display()
      end
    else
      vim.ui.input({ prompt = messages.assign_key_prompt }, function(input)
        if input and input ~= "" then
          local success, msg = tagonaut_api.assign_key_to_tag(selection.tag, input)
          if success then
            print(msg)
            update_display()
          end
        end
      end)
    end
  end
end

function M.clear_all_keys()
  if not (main_window and api.nvim_win_is_valid(main_window)) then
    return
  end

  local cursor = api.nvim_win_get_cursor(main_window)
  local selected_index = cursor[1]

  vim.ui.input({ prompt = messages.confirm_clear_all_keys }, function(input)
    if input and input:lower() == "y" then
      local success, msg = tagonaut_api.clear_all_keys()
      if success then
        print(msg)
        update_display()
      end
    end
  end)
end

function M.rename_tag()
  if not (main_window and api.nvim_win_is_valid(main_window)) then
    return
  end

  local cursor = api.nvim_win_get_cursor(main_window)
  local selected_index = cursor[1]

  if selected_index > 0 and selected_index <= #M.tag_list then
    local selection = M.tag_list[selected_index]
    vim.ui.input({ prompt = "Enter new tag name: " }, function(new_tag)
      if new_tag and new_tag ~= "" then
        local success, msg = tagonaut_api.rename_tag(selection.tag, new_tag, selection.type == "global")
        if success then
          print(msg)
          M.display_tags(M.tag_list, M.title, M.include_global)
        else
          print(msg)
        end
      end
    end)
  end
end

function M.list_tags(include_global)
  local tag_list = tagonaut_api.list_tags(include_global)
  
  if not tag_list or #tag_list == 0 then
    local msg = include_global and "No tags found (global or local)" or "No local tags found"
    vim.notify(msg, vim.log.levels.INFO)
    return
  end

  local title = include_global and "All Tags" or "Local Tags"
  M.display_tags(tag_list, title, include_global)
end

return M
