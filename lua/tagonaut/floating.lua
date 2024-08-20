local M = {}
local api = vim.api
local config = require("tagonaut.config").options
local tagonaut_api = require "tagonaut.api"
local messages = require "tagonaut.messages"
local utils = require "tagonaut.utils"
local symbols = require "tagonaut.symbols"

local window
local buffer
local deleted_tags = {}

local function create_or_update_window()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  if not buffer or not api.nvim_buf_is_valid(buffer) then
    buffer = api.nvim_create_buf(false, true)
  end

  if not window or not api.nvim_win_is_valid(window) then
    window = api.nvim_open_win(buffer, true, opts)
  else
    api.nvim_win_set_config(window, opts)
  end

  vim.api.nvim_set_option_value("cursorline", true, { win = window })

  local function map(mode, lhs, rhs)
    vim.api.nvim_buf_set_keymap(buffer, mode, lhs, rhs, { noremap = true, silent = true })
  end

  map("n", config.floating_window.close, ':lua require("tagonaut.floating").close()<CR>')
  map("n", config.floating_window.select, ':lua require("tagonaut.floating").select()<CR>')
  map("n", config.floating_window.delete, ':lua require("tagonaut.floating").delete()<CR>')
  map("n", config.floating_window.clear, ':lua require("tagonaut.floating").clear()<CR>')
  map("n", config.floating_window.assign_key, ':lua require("tagonaut.floating").toggle_key_assignment()<CR>')
  map("n", config.floating_window.clear_all_keys, ':lua require("tagonaut.floating").clear_all_keys()<CR>')
  map("n", config.floating_window.rename, ':lua require("tagonaut.floating").rename_tag()<CR>')
end

function M.rename_tag()
  local cursor = api.nvim_win_get_cursor(window)
  local selected_index = cursor[1] - 2

  if selected_index > 0 and selected_index <= #M.tag_list then
    local selection = M.tag_list[selected_index]
    vim.ui.input({ prompt = "Enter new tag name: " }, function(new_tag)
      if new_tag and new_tag ~= "" then
        local success, msg = tagonaut_api.rename_tag(selection.tag, new_tag, selection.type == "global")
        if success then
          print(msg)
          M.display_tags(tagonaut_api.list_tags(M.include_global), M.title, M.include_global)
          api.nvim_win_set_cursor(window, { selected_index + 2, 0 })
        else
          print(msg)
        end
      end
    end)
  end
end

function M.display_tags(tag_list, title, include_global)
  create_or_update_window()

  local lines = { title, string.rep("-", #title) }

  for i, tag in ipairs(tag_list) do
    local is_directory = vim.fn.isdirectory(tag.path) == 1
    local icon, _ = utils.get_icon(tag.path, is_directory)
    local line = icon .. " " .. tag.tag
    if include_global and tag.type == "global" then
      line = line .. " (G)"
    end
    if tag.symbol then
      line = line .. " [" .. tag.symbol.kind .. "]"
    end
    for key, t in pairs(tagonaut_api.keyed_tags) do
      if t == tag.tag then
        line = line .. " [" .. key .. "]"
        break
      end
    end
    if deleted_tags[tag.tag] then
      line = "~~" .. line .. "~~"
    end
    lines[i + 2] = line
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = buffer })
  api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buffer })

  M.tag_list = tag_list
  M.include_global = include_global
  M.title = title
end

function M.close()
  if window and api.nvim_win_is_valid(window) then
    api.nvim_win_close(window, true)
    window = nil
  end
  if buffer and api.nvim_buf_is_valid(buffer) then
    api.nvim_buf_delete(buffer, { force = true })
    buffer = nil
  end
  deleted_tags = {}
end

function M.select()
  local cursor = api.nvim_win_get_cursor(window)
  local selected_index = cursor[1] - 2

  if selected_index > 0 and selected_index <= #M.tag_list then
    local selection = M.tag_list[selected_index]
    if not deleted_tags[selection.tag] then
      M.close()

      local success, msg = tagonaut_api.jump_to_tag(selection.tag, selection.type == "global", symbols)
      if not success then
        print("Failed to jump to tag: " .. msg)
      end
    else
      print "Cannot select a deleted tag"
    end
  end
end

function M.delete()
  local cursor = api.nvim_win_get_cursor(window)
  local selected_index = cursor[1] - 2

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
    api.nvim_win_set_cursor(window, { selected_index + 2, 0 })
  end
end

function M.clear()
  local prompt = M.include_global and messages.confirm_clear_all_tags or messages.confirm_clear_local_tags
  vim.ui.input({ prompt = prompt }, function(input)
    if input and input:lower() == "y" then
      local success, msg = tagonaut_api.clear_all_tags(M.include_global)
      if success then
        print(msg)
        M.close()
      end
    else
      print(messages.operation_cancelled)
    end
  end)
end

function M.list_tags(include_global)
  local tag_list = tagonaut_api.list_tags(include_global)
  local title = include_global and "All Tags" or "Local Tags"
  M.display_tags(tag_list, title, include_global)
end

function M.toggle_key_assignment()
  local cursor = api.nvim_win_get_cursor(window)
  local selected_index = cursor[1] - 2

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
        M.display_tags(M.tag_list, M.title, M.include_global)
        api.nvim_win_set_cursor(window, { selected_index + 2, 0 })
      end
    else
      vim.ui.input({ prompt = messages.assign_key_prompt }, function(input)
        if input and #input == 1 then
          local success, msg = tagonaut_api.assign_key_to_tag(selection.tag, input)
          if success then
            print(msg)
            M.display_tags(M.tag_list, M.title, M.include_global)
            api.nvim_win_set_cursor(window, { selected_index + 2, 0 })
          end
        end
      end)
    end
  end
end

function M.clear_all_keys()
  vim.ui.input({ prompt = messages.confirm_clear_all_keys }, function(input)
    if input and input:lower() == "y" then
      local success, msg = tagonaut_api.clear_all_keys()
      if success then
        print(msg)
        M.display_tags(M.tag_list, M.title, M.include_global)
      end
    end
  end)
end

return M
