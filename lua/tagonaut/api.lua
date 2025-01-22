local M = {}
local Path = require "plenary.path"
local config = require("tagonaut.config").options
local messages = require "tagonaut.messages"
local extmarks = require "tagonaut.extmarks"


M.tags = { global = {}, workspace = {}, extmarks_visible = {} }
M.keyed_tags = {}
M.temp_deleted_tags = {}
M.temp_deleted_keys = {}

--- Get the current workspace path
-- @return string: The current workspace path
function M.get_workspace()
  return vim.fn.getcwd(-1, -1)
end

--- Get tag information for a given tag name and scope
-- @param tag_name string: The name of the tag
-- @param is_global boolean: Whether the tag is global or workspace-specific
-- @return table|nil: The tag information if found, nil otherwise
function M.get_tag_info(tag_name, is_global)
  local workspace = M.get_workspace()
  return is_global and M.tags.global[tag_name]
    or (M.tags.workspace[workspace] and M.tags.workspace[workspace][tag_name])
end

--- Set tag information for a given tag name and scope
-- @param tag_name string: The name of the tag
-- @param tag_info table: The tag information to set
-- @param is_global boolean: Whether the tag is global or workspace-specific
function M.set_tag_info(tag_name, tag_info, is_global)
  local workspace = M.get_workspace()
  if is_global then
    M.tags.global[tag_name] = tag_info
  else
    if not M.tags.workspace[workspace] then
      M.tags.workspace[workspace] = {}
      M.tags.extmarks_visible[workspace] = true
    end
    M.tags.workspace[workspace][tag_name] = tag_info
  end
end

--- Remove tag information for a given tag name and scope
-- @param tag_name string: The name of the tag
-- @param is_global boolean: Whether the tag is global or workspace-specific
-- @return boolean: True if the tag was removed, false otherwise
function M.remove_tag_info(tag_name, is_global)
  local workspace = M.get_workspace()
  local removed = false
  if is_global then
    if M.tags.global[tag_name] then
      M.tags.global[tag_name] = nil
      removed = true
    end
  else
    if M.tags.workspace[workspace] and M.tags.workspace[workspace][tag_name] then
      M.tags.workspace[workspace][tag_name] = nil
      removed = true
    end
  end
  return removed
end

--- Add a symbol tag
-- @param tag_name string: The name of the tag
-- @param is_global boolean: Whether the tag is global or workspace-specific
-- @param symbols table: The symbols module
-- @return boolean, string: Success status and message
function M.add_symbol_tag(tag_name, is_global, symbols)
  local file_path = vim.fn.expand "%:p"
  local symbol_info = symbols.get_symbol_at_cursor()

  if not tag_name or not file_path or not symbol_info then
    return false, messages.invalid_tag_info
  end

  local tag_info = {
    path = file_path,
    symbol = symbol_info,
    type = "symbol",
    line = symbol_info.range.start.line,
  }

  M.set_tag_info(tag_name, tag_info, is_global)
  M.save_tags()
  M.auto_assign_key(tag_name)
  return true, messages.tag_added(tag_name, is_global)
end

--- Jump to a tag
-- @param tag_name string: The name of the tag
-- @param is_global boolean: Whether the tag is global or workspace-specific
-- @param symbols table: The symbols module
-- @return boolean, string: Success status and message
function M.jump_to_tag(tag_name, is_global, symbols)
  local tag_info = M.get_tag_info(tag_name, is_global)

  if not tag_info then
    return false, messages.tag_not_found(tag_name)
  end

  vim.cmd("edit " .. tag_info.path)

  if tag_info.symbol and symbols then
    return symbols.jump_to_symbol(tag_info.symbol, tag_info.path)
  elseif tag_info.line then
    vim.api.nvim_win_set_cursor(0, { tag_info.line, 0 })
    vim.cmd "normal! zz"
    return true, messages.jumped_to_tag(tag_name)
  else
    return false, messages.invalid_tag_info
  end
end

--- Load tags from the config file
function M.load_tags()
  local file_path = config.config_file
  if Path:new(file_path):exists() then
    local content = Path:new(file_path):read()
    if content then
      local data = vim.fn.json_decode(content)
      M.tags = data.tags or { global = {}, workspace = {}, extmarks_visible = {} }
      M.keyed_tags = data.keyed_tags or {}
    else
      M.tags = { global = {}, workspace = {}, extmarks_visible = {} }
      M.keyed_tags = {}
    end
  else
    M.tags = { global = {}, workspace = {}, extmarks_visible = {} }
    M.keyed_tags = {}
  end

  for workspace, _ in pairs(M.tags.workspace) do
    if M.tags.extmarks_visible[workspace] == nil then
      M.tags.extmarks_visible[workspace] = true
    end
  end
end

--- Save tags to the config file
function M.save_tags()
  local file_path = config.config_file
  local data_to_save = {
    tags = M.tags,
    keyed_tags = M.keyed_tags,
  }
  Path:new(file_path):write(vim.fn.json_encode(data_to_save), "w")
end

--- Add a tag
-- @param tag_name string: The name of the tag
-- @param is_global boolean: Whether the tag is global or workspace-specific
-- @return boolean, string: Success status and message
function M.add_tag(tag_name, is_global)
  local file_path = vim.fn.expand "%:p"
  local line_number = vim.api.nvim_win_get_cursor(0)[1]

  if not tag_name or not file_path or not line_number then
    return false, messages.invalid_tag_info
  end

  local tag_info = {
    path = file_path,
    line = line_number,
  }

  M.set_tag_info(tag_name, tag_info, is_global)
  M.save_tags()
  M.auto_assign_key(tag_name)
  M.update_extmarks()
  return true, messages.tag_added(tag_name, is_global)
end

--- Rename a tag
-- @param old_tag string: The current name of the tag
-- @param new_tag string: The new name for the tag
-- @param is_global boolean: Whether the tag is global or workspace-specific
-- @return boolean, string: Success status and message
function M.rename_tag(old_tag, new_tag, is_global)
  local tag_info = M.get_tag_info(old_tag, is_global)

  if tag_info then
    M.remove_tag_info(old_tag, is_global)
    M.set_tag_info(new_tag, tag_info, is_global)

    for key, tag in pairs(M.keyed_tags) do
      if tag == old_tag then
        M.keyed_tags[key] = new_tag
        break
      end
    end

    M.save_tags()
    M.update_extmarks()
    return true, messages.tag_renamed(old_tag, new_tag)
  end

  return false, messages.tag_not_found(old_tag)
end

--- List all tags
-- @param include_global boolean: Whether to include global tags in the list
-- @return table: List of all tags
function M.list_tags(include_global)
  local workspace = M.get_workspace()
  local tag_list = {}

  if M.tags.workspace[workspace] then
    for tag, info in pairs(M.tags.workspace[workspace]) do
      table.insert(tag_list, { tag = tag, path = info.path, line = info.line, type = "local" })
    end
  end

  if include_global then
    for tag, info in pairs(M.tags.global) do
      table.insert(tag_list, { tag = tag, path = info.path, line = info.line, type = "global" })
    end
  end

  return tag_list
end

--- Delete a tag
-- @param tag string: The name of the tag to delete
-- @param is_global boolean: Whether the tag is global or workspace-specific
-- @return boolean, string: Success status and message
function M.delete_tag(tag, is_global)
  local tag_info = M.get_tag_info(tag, is_global)
  if tag_info then
    M.remove_tag_info(tag, is_global)
    table.insert(M.temp_deleted_tags, { tag = tag, info = tag_info, is_global = is_global })

    for key, assigned_tag in pairs(M.keyed_tags) do
      if assigned_tag == tag then
        M.temp_deleted_keys[tag] = key
        M.keyed_tags[key] = nil
        break
      end
    end

    M.save_tags()
    M.update_extmarks()
    return true, messages.tag_deleted(tag)
  end
  return false, messages.tag_not_found(tag)
end

--- Restore a deleted tag
-- @param index number: The index of the deleted tag to restore
-- @return boolean, string: Success status and message
function M.restore_deleted_tag(index)
  local deleted_tag = table.remove(M.temp_deleted_tags, index)
  if deleted_tag then
    M.set_tag_info(deleted_tag.tag, deleted_tag.info, deleted_tag.is_global)

    if M.temp_deleted_keys[deleted_tag.tag] then
      local key = M.temp_deleted_keys[deleted_tag.tag]
      M.keyed_tags[key] = deleted_tag.tag
      M.temp_deleted_keys[deleted_tag.tag] = nil
    end

    M.update_extmarks()
    M.save_tags()
    return true, messages.tag_restored(deleted_tag.tag)
  end
  return false, messages.tag_not_found "deleted tag"
end

--- Clear all tags
-- @param include_global boolean: Whether to clear global tags as well
-- @return boolean, string: Success status and message
function M.clear_all_tags(include_global)
  local workspace = M.get_workspace()
  if include_global then
    M.tags = { global = {}, workspace = {}, extmarks_visible = {} }
  else
    M.tags.workspace[workspace] = {}
  end
  M.save_tags()
  M.update_extmarks()
  return true, messages.tags_cleared(include_global)
end

--- Automatically assign a key to a tag
-- @param tag string: The name of the tag
function M.auto_assign_key(tag)
  if #config.auto_assign_keys > 0 then
    for _, key in ipairs(config.auto_assign_keys) do
      if M.keyed_tags[key] == nil then
        M.assign_key_to_tag(tag, key)
        break
      end
    end
  end
end

--- Assign a key to a tag
-- @param tag string: The name of the tag
-- @param key string: The key to assign
-- @return boolean, string: Success status and message
function M.assign_key_to_tag(tag, key)
  M.keyed_tags[key] = tag
  M.save_tags()
  return true, messages.key_assigned(key, tag)
end

--- Remove a key from a tag
-- @param key string: The key to remove
-- @return boolean, string: Success status and message
function M.remove_key_from_tag(key)
  if M.keyed_tags[key] then
    local tag = M.keyed_tags[key]
    M.keyed_tags[key] = nil
    M.save_tags()
    return true, messages.key_removed(key, tag)
  end
  return false, messages.key_not_found(key)
end

--- Clear all assigned keys
-- @return boolean, string: Success status and message
function M.clear_all_keys()
  M.keyed_tags = {}
  M.save_tags()
  return true, messages.all_keys_cleared
end

--- Get a tag by its assigned key
-- @param key string: The key to look up
-- @return string|nil: The tag name if found, nil otherwise
function M.get_tag_by_key(key)
  return M.keyed_tags[key]
end

--- Get the next tag in the sequence
-- @param current_tag string: The current tag name
-- @param direction number: The direction to move (-1 for previous, 1 for next)
-- @return table|nil: The next tag entry if found, nil otherwise
function M.get_next_tag(current_tag, direction)
  local workspace = M.get_workspace()
  local all_tags = {}

  for tag, info in pairs(M.tags.global) do
    table.insert(all_tags, { tag = tag, info = info, is_global = true })
  end
  if M.tags.workspace[workspace] then
    for tag, info in pairs(M.tags.workspace[workspace]) do
      table.insert(all_tags, { tag = tag, info = info, is_global = false })
    end
  end

  table.sort(all_tags, function(a, b)
    if a.info.path == b.info.path then
      return a.info.line < b.info.line
    end
    return a.info.path < b.info.path
  end)

  local current_index = 0
  for i, tag_entry in ipairs(all_tags) do
    if tag_entry.tag == current_tag then
      current_index = i
      break
    end
  end

  local next_index = current_index + direction
  if next_index < 1 then
    next_index = #all_tags
  elseif next_index > #all_tags then
    next_index = 1
  end

  return all_tags[next_index]
end

--- Toggle the visibility of extmarks for a workspace
-- @param workspace string: The workspace to toggle visibility for
-- @return boolean: The new visibility state
function M.toggle_extmarks_visibility(workspace)
  M.tags.extmarks_visible[workspace] = not M.tags.extmarks_visible[workspace]
  M.save_tags()
  return M.tags.extmarks_visible[workspace]
end

--- Update extmarks for all buffers
function M.update_extmarks()
  extmarks.update_all_buffers_extmarks(M.tags)
end

--- Trigger a keyed tag action
-- @return boolean, string: Success status and message
function M.trigger_keyed_tag()
  -- Debug: Show current keyed tags
  local debug_msg = "Available keyed tags: "
  for k, v in pairs(M.keyed_tags) do
    debug_msg = debug_msg .. string.format("[%s]=%s ", k, v)
  end
  vim.api.nvim_echo({ { debug_msg .. " > ", "Comment" } }, false, {})
  vim.cmd "redraw"

  local input = ""
  local potential_matches = {}

  -- Get the first key
  local char = vim.fn.nr2char(vim.fn.getchar())
  input = input .. char

  -- Find potential matches
  for key, _ in pairs(M.keyed_tags) do
    if key:sub(1, #input) == input then
      potential_matches[key] = true
    end
  end

  -- If there are potential multi-char matches, wait for more input
  while next(potential_matches) and not M.keyed_tags[input] do
    -- Show remaining potential matches
    local match_msg = "Potential matches: "
    for key, _ in pairs(potential_matches) do
      match_msg = match_msg .. "[" .. key .. "] "
    end
    vim.api.nvim_echo({ { match_msg, "Comment" } }, false, {})
    vim.cmd "redraw"

    -- Get next character
    char = vim.fn.nr2char(vim.fn.getchar())
    input = input .. char

    -- Update potential matches
    local new_matches = {}
    for key, _ in pairs(potential_matches) do
      if key:sub(1, #input) == input then
        new_matches[key] = true
      end
    end
    potential_matches = new_matches

    -- Break if no more potential matches or exact match found
    if not next(potential_matches) or M.keyed_tags[input] then
      break
    end
  end

  -- Clear the prompt line
  vim.api.nvim_echo({ { "", "" } }, false, {})

  -- Check if key exists in keyed_tags
  if M.keyed_tags[input] then
    local tag_info = M.get_tag_info(M.keyed_tags[input], true) or M.get_tag_info(M.keyed_tags[input], false)

    if tag_info then
      -- Jump to file and position
      vim.cmd("edit " .. tag_info.path)
      if tag_info.symbol then
        local success, msg = require("tagonaut.symbols").jump_to_symbol(tag_info.symbol, tag_info.path)
        vim.api.nvim_echo({ { msg, success and "Normal" or "ErrorMsg" } }, false, {})
        return success
      else
        vim.api.nvim_win_set_cursor(0, { tag_info.line, 0 })
        vim.cmd "normal! zz"
        vim.api.nvim_echo({ { messages.jumped_to_tag(M.keyed_tags[input]), "Normal" } }, false, {})
        return true
      end
    else
      vim.api.nvim_echo({ { messages.tag_not_found(M.keyed_tags[input]), "ErrorMsg" } }, false, {})
      return false
    end
  else
    vim.api.nvim_echo({ { messages.no_tag_for_key(input), "WarningMsg" } }, false, {})
    return false
  end
end

--- Switch to a tag's file
-- @param tag_name string: The name of the tag
-- @param is_global boolean: Whether the tag is global or workspace-specific
-- @return boolean, string: Success status and message
function M.switch_to_tag_file(tag_name, is_global)
    local tag_info = M.get_tag_info(tag_name, is_global)

    if not tag_info then
        return false, messages.tag_not_found(tag_name)
    end

    -- Check if buffer is already open
    local bufnr = vim.fn.bufnr(tag_info.path)
    local was_open = bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr)

    if was_open then
        -- Switch to buffer without moving cursor
        vim.cmd("buffer " .. bufnr)
        return true, messages.switched_to_buffer(tag_name)
    else
        -- Open file and move cursor to tag position
        vim.cmd("edit " .. tag_info.path)
        vim.api.nvim_win_set_cursor(0, { tag_info.line, 0 })
        vim.cmd "normal! zz"
        return true, messages.jumped_to_tag(tag_name)
    end
end

--- Trigger a keyed file action
-- @return boolean, string: Success status and message
function M.trigger_keyed_file()
    -- Show available keys
    local debug_msg = "Available keyed tags: "
    for k, v in pairs(M.keyed_tags) do
        debug_msg = debug_msg .. string.format("[%s]=%s ", k, v)
    end
    vim.api.nvim_echo({ { debug_msg .. " > ", "Comment" } }, false, {})
    vim.cmd "redraw"

    local input = ""
    local potential_matches = {}

    -- Get first key press
    local char = vim.fn.nr2char(vim.fn.getchar())
    input = input .. char

    -- Find potential matches
    for key, _ in pairs(M.keyed_tags) do
        if key:sub(1, #input) == input then
            potential_matches[key] = true
        end
    end

    -- Handle multi-character keys
    while next(potential_matches) and not M.keyed_tags[input] do
        local match_msg = "Potential matches: "
        for key, _ in pairs(potential_matches) do
            match_msg = match_msg .. "[" .. key .. "] "
        end
        vim.api.nvim_echo({ { match_msg, "Comment" } }, false, {})
        vim.cmd "redraw"

        char = vim.fn.nr2char(vim.fn.getchar())
        input = input .. char

        local new_matches = {}
        for key, _ in pairs(potential_matches) do
            if key:sub(1, #input) == input then
                new_matches[key] = true
            end
        end
        potential_matches = new_matches

        if not next(potential_matches) or M.keyed_tags[input] then
            break
        end
    end

    -- Clear prompt
    vim.api.nvim_echo({ { "", "" } }, false, {})

    -- Handle the key
    if M.keyed_tags[input] then
        local tag = M.keyed_tags[input]
        -- Try global first, then local
        local success, msg = M.switch_to_tag_file(tag, true)
        if not success then
            success, msg = M.switch_to_tag_file(tag, false)
        end
        vim.api.nvim_echo({ { msg, success and "Normal" or "ErrorMsg" } }, false, {})
        return success
    else
        vim.api.nvim_echo({ { messages.no_tag_for_key(input), "WarningMsg" } }, false, {})
        return false
    end
end

return M
