local M = {}
local Path = require "plenary.path"
local config = require("tagonaut.config").options
local messages = require "tagonaut.messages"
local extmarks = require "tagonaut.extmarks"

M.workspaces = {}
M.temp_deleted_tags = {}
local current_workspace = nil

--- Set the current workspace
--- @param workspace_path string: The path to set as current workspace
function M.set_workspace(workspace_path)
  current_workspace = workspace_path
  if not M.workspaces[current_workspace] then
    M.workspaces[current_workspace] = {
      name = M.get_workspace_name(workspace_path),
      counter = 0,
      tags = {},
      extmarks_visible = true,
      last_accessed = os.time(),
      ignored = false,
    }
  else
    M.workspaces[current_workspace].last_accessed = os.time()
    M.workspaces[current_workspace].ignored = M.workspaces[current_workspace].ignored or false
  end
  M.save_tags()
  M.update_extmarks()
end

--- Get the current workspace path
--- @return string|nil: The current workspace path
function M.get_workspace()
  if not current_workspace then
    M.set_workspace(vim.fn.getcwd(-1, -1))
  end
  return current_workspace
end

--- Get workspace name from path
--- @param path string: The workspace path
--- @return string: The workspace name
function M.get_workspace_name(path)
  return vim.fn.fnamemodify(path, ":t")
end

--- Get tag information for a given tag ID
--- @param tag_id number: The ID of the tag
--- @return table|nil: The tag information if found, nil otherwise
function M.get_tag_info(tag_id)
  return M.workspaces[current_workspace] and M.workspaces[current_workspace].tags[tag_id]
end

--- Get next unique tag ID for workspace
--- @return number: The next unique ID
function M.get_next_tag_id()
  M.workspaces[current_workspace].counter = M.workspaces[current_workspace].counter + 1
  return M.workspaces[current_workspace].counter
end

--- Auto assign a shortcut to a tag
--- @param tag_id string|number: The ID of the tag
--- @return string|nil: The assigned shortcut, or nil if none available
function M.auto_assign_shortcut(tag_id)
  local tag_id_str = tostring(tag_id)

  if not M.workspaces[current_workspace] or not M.workspaces[current_workspace].tags then
    return nil
  end

  local used_shortcuts = {}
  for _, tag_info in pairs(M.workspaces[current_workspace].tags) do
    if tag_info.shortcut then
      used_shortcuts[tag_info.shortcut] = true
    end
  end

  for _, shortcut in ipairs(config.auto_assign_keys) do
    if not used_shortcuts[shortcut] then
      if M.workspaces[current_workspace].tags[tag_id_str] then
        M.workspaces[current_workspace].tags[tag_id_str].shortcut = shortcut
        M.save_tags()
        return shortcut
      end
      return nil
    end
  end

  return nil
end

--- Set tag information
--- @param tag_info table: The tag information to set
--- @return string: The tag ID
function M.set_tag_info(tag_info)
  local tag_id = tostring(M.get_next_tag_id())
  M.workspaces[current_workspace].tags[tag_id] = tag_info
  return tag_id
end

--- Remove tag information
--- @param tag_id number: The ID of the tag to remove
--- @return boolean: True if the tag was removed, false otherwise
function M.remove_tag_info(tag_id)
  if M.workspaces[current_workspace] and M.workspaces[current_workspace].tags[tag_id] then
    M.workspaces[current_workspace].tags[tag_id] = nil
    return true
  end
  return false
end

--- Add a symbol tag
--- @param tag_name string: The name of the tag
--- @param symbols table: The symbols module
--- @return boolean, string: Success status and message
function M.add_symbol_tag(tag_name, symbols)
  local file_path = vim.fn.expand "%:p"
  local symbol_info = symbols.get_symbol_at_cursor()

  if not tag_name or not file_path or not symbol_info then
    return false, messages.invalid_tag_info
  end

  local tag_info = {
    path = file_path,
    symbol = symbol_info,
    name = tag_name,
    line = symbol_info.range.start.line + 1,
  }

  local tag_id = M.set_tag_info(tag_info)
  local numeric_id = tonumber(tag_id)
  if numeric_id then
    local assigned_shortcut = M.auto_assign_shortcut(numeric_id)
    if assigned_shortcut then
      tag_info.shortcut = assigned_shortcut
    end
  end

  M.save_tags()
  M.update_extmarks()
  return true, messages.tag_added(tag_name)
end

--- Jump to a tag
--- @param tag_id number: The ID of the tag
--- @param symbols table: The symbols module
--- @return boolean, string: Success status and message
function M.jump_to_tag(tag_id, symbols)
  local tag_info = M.get_tag_info(tag_id)

  if not tag_info then
    return false, messages.tag_not_found(tag_id)
  end

  vim.cmd("edit " .. tag_info.path)

  if tag_info.symbol and symbols then
    return symbols.jump_to_symbol(tag_info.symbol, tag_info.path)
  elseif tag_info.line then
    vim.api.nvim_win_set_cursor(0, { tag_info.line, 0 })
    vim.cmd "normal! zz"
    return true, messages.jumped_to_tag(tag_info.name)
  else
    return false, messages.invalid_tag_info
  end
end

--- Load tags from the config file
function M.load_tags()
  local file_path = config.config_file
  local path = Path:new(file_path)

  if not path:parent():exists() then
    path:parent():mkdir { parents = true }
  end

  if not path:exists() then
    M.workspaces = {}
    path:write(vim.fn.json_encode(M.workspaces), "w")
    return
  end

  local content = path:read()
  if content then
    M.workspaces = vim.fn.json_decode(content)
  else
    M.workspaces = {}
  end
end

--- Save tags to the config file
function M.save_tags()
  local file_path = config.config_file
  local path = Path:new(file_path)

  if not path:parent():exists() then
    path:parent():mkdir { parents = true }
  end

  path:write(vim.fn.json_encode(M.workspaces), "w")
end

--- Add a tag
--- @param tag_name string: The name of the tag
--- @return boolean, string: Success status and message
function M.add_tag(tag_name)
  local file_path = vim.fn.expand "%:p"
  local line_number = vim.api.nvim_win_get_cursor(0)[1]

  if not tag_name or not file_path or not line_number then
    return false, messages.invalid_tag_info
  end

  local tag_info = {
    path = file_path,
    line = line_number,
    name = tag_name,
  }

  local tag_id = M.set_tag_info(tag_info)
  local numeric_id = tonumber(tag_id)
  if numeric_id then
    local assigned_shortcut = M.auto_assign_shortcut(numeric_id)
    if assigned_shortcut then
      tag_info.shortcut = assigned_shortcut
    end
  end

  M.save_tags()
  M.update_extmarks()
  return true, messages.tag_added(tag_name)
end

--- Rename a tag
--- @param tag_id number: The ID of the tag
--- @param new_name string: The new name for the tag
--- @return boolean, string: Success status and message
function M.rename_tag(tag_id, new_name)
  if M.workspaces[current_workspace] and M.workspaces[current_workspace].tags[tag_id] then
    local old_name = M.workspaces[current_workspace].tags[tag_id].name
    M.workspaces[current_workspace].tags[tag_id].name = new_name
    M.save_tags()
    M.update_extmarks()
    return true, messages.tag_renamed(old_name, new_name)
  end
  return false, messages.tag_not_found(tag_id)
end

--- List all tags
--- @return table: List of all tags
function M.list_tags()
  local tag_list = {}

  if M.workspaces[current_workspace] and M.workspaces[current_workspace].tags then
    for id, info in pairs(M.workspaces[current_workspace].tags) do
      table.insert(tag_list, {
        id = id,
        name = info.name,
        path = info.path,
        line = info.line,
        shortcut = info.shortcut,
      })
    end
  end

  return tag_list
end

--- Delete a tag
--- @param tag_id number: The ID of the tag to delete
--- @return boolean, string: Success status and message
function M.delete_tag(tag_id)
  local tag_info = M.get_tag_info(tag_id)
  if tag_info then
    M.remove_tag_info(tag_id)
    table.insert(M.temp_deleted_tags, { id = tag_id, info = tag_info })
    M.save_tags()
    M.update_extmarks()
    return true, messages.tag_deleted(tag_info.name)
  end
  return false, messages.tag_not_found(tag_id)
end

--- Restore a deleted tag
--- @param index number: The index of the deleted tag to restore
--- @return boolean, string: Success status and message
function M.restore_deleted_tag(index)
  local deleted_tag = table.remove(M.temp_deleted_tags, index)
  if deleted_tag then
    M.workspaces[current_workspace].tags[deleted_tag.id] = deleted_tag.info
    M.update_extmarks()
    M.save_tags()
    return true, messages.tag_restored(deleted_tag.info.name)
  end
  return false, messages.tag_not_found "deleted tag"
end

--- Clear all tags
--- @return boolean, string: Success status and message
function M.clear_all_tags()
  if M.workspaces[current_workspace] then
    M.workspaces[current_workspace].tags = {}
    M.save_tags()
    M.update_extmarks()
    return true, messages.tags_cleared()
  end
  return false, messages.workspace_not_found
end

--- Update extmarks for all buffers
function M.update_extmarks()
  local workspace_data = M.workspaces[current_workspace]
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      extmarks.update_extmarks(buf, workspace_data)
    end
  end
end

--- Trigger a keyed tag action
--- @return boolean, string: Success status and message
function M.trigger_keyed_tag()
  if not current_workspace then
    M.set_workspace(vim.fn.getcwd())
  end

  if vim.tbl_isempty(M.workspaces) then
    M.load_tags()
  end

  local function get_matches_msg(matches)
    local msg = "Matching shortcuts: "
    for shortcut, info in pairs(matches) do
      msg = msg .. string.format("[%s]=%s ", shortcut, info.name)
    end
    return msg
  end

  local input = ""
  local matches = {}

  if M.workspaces[current_workspace] and M.workspaces[current_workspace].tags then
    for _, info in pairs(M.workspaces[current_workspace].tags) do
      if info.shortcut then
        matches[info.shortcut] = info
      end
    end
  end

  while true do
    vim.api.nvim_echo({ { get_matches_msg(matches) .. " > " .. input, "Comment" } }, false, {})
    vim.cmd "redraw"

    local char = vim.fn.nr2char(vim.fn.getchar())
    input = input .. char

    matches = {}
    if M.workspaces[current_workspace] and M.workspaces[current_workspace].tags then
      for _, info in pairs(M.workspaces[current_workspace].tags) do
        if info.shortcut and info.shortcut:find("^" .. vim.pesc(input)) then
          matches[info.shortcut] = info
        end
      end
    end

    if vim.tbl_count(matches) == 0 then
      local msg = messages.no_tag_for_shortcut(input)
      vim.api.nvim_echo({ { msg, "WarningMsg" } }, false, {})
      return false, msg
    end

    if vim.tbl_count(matches) == 1 then
      local _, tag_info = next(matches)
      vim.cmd("edit " .. tag_info.path)
      if tag_info.symbol then
        local success, msg = require("tagonaut.symbols").jump_to_symbol(tag_info.symbol, tag_info.path)
        vim.api.nvim_echo({ { msg, success and "Normal" or "ErrorMsg" } }, false, {})
        return success, msg
      else
        vim.api.nvim_win_set_cursor(0, { tag_info.line, 0 })
        vim.cmd "normal! zz"
        local msg = messages.jumped_to_tag(tag_info.name)
        vim.api.nvim_echo({ { msg, "Normal" } }, false, {})
        return true, msg
      end
    end
  end
end

--- Switch to a tag's file
--- @param tag_id number: The ID of the tag
--- @return boolean, string: Success status and message
function M.switch_to_tag_file(tag_id)
  local tag_info = M.get_tag_info(tag_id)

  if not tag_info then
    return false, messages.tag_not_found(tag_id)
  end

  local bufnr = vim.fn.bufnr(tag_info.path)
  local was_open = bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr)

  if was_open then
    vim.cmd("buffer " .. bufnr)
    return true, messages.switched_to_buffer(tag_info.name)
  else
    vim.cmd("edit " .. tag_info.path)
    vim.api.nvim_win_set_cursor(0, { tag_info.line, 0 })
    vim.cmd "normal! zz"
    return true, messages.jumped_to_tag(tag_info.name)
  end
end

--- Trigger a keyed file action
--- @return boolean, string: Success status and message
function M.trigger_keyed_file()
  local success, msg = M.trigger_keyed_tag()
  if success then
    msg = "Switched to file: " .. msg
  end
  return success, msg
end

--- Get a tag by its shortcut
--- @param shortcut string: The shortcut to look up
--- @return table|nil: The tag information if found, nil otherwise
function M.get_tag_by_shortcut(shortcut)
  if M.workspaces[current_workspace] and M.workspaces[current_workspace].tags then
    for _, info in pairs(M.workspaces[current_workspace].tags) do
      if info.shortcut == shortcut then
        return info
      end
    end
  end
  return nil
end

--- Set a shortcut for a tag
--- @param tag_id number: The ID of the tag
--- @param shortcut string: The shortcut to set
--- @return boolean, string: Success status and message
function M.set_shortcut(tag_id, shortcut)
  if M.workspaces[current_workspace] and M.workspaces[current_workspace].tags[tag_id] then
    M.workspaces[current_workspace].tags[tag_id].shortcut = shortcut
    M.save_tags()
    return true, messages.shortcut_set(shortcut, M.workspaces[current_workspace].tags[tag_id].name)
  end
  return false, messages.tag_not_found(tag_id)
end

return M
