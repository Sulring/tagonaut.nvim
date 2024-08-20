# api.lua

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
  return is_global and M.tags.global[tag_name] or (M.tags.workspace[workspace] and M.tags.workspace[workspace][tag_name])
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
  return false, messages.tag_not_found("deleted tag")
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
  local char = vim.fn.getchar()
  local key = vim.fn.nr2char(char)

  if M.keyed_tags[key] then
    local tag_info = M.get_tag_info(M.keyed_tags[key], true) or M.get_tag_info(M.keyed_tags[key], false)
    if tag_info then
      vim.cmd("edit " .. tag_info.path)
      vim.api.nvim_win_set_cursor(0, { tag_info.line, 0 })
      vim.cmd "normal! zz"
      return true, messages.jumped_to_tag(M.keyed_tags[key])
    else
      return false, messages.tag_not_found(M.keyed_tags[key])
    end
  else
    return false, messages.no_tag_for_key(key)
  end
end

return M



# commands.lua

local M = {}
local config = require("tagonaut.config").options
local api = require "tagonaut.api"
local symbols = require "tagonaut.symbols"

function M.setup()
  vim.api.nvim_set_keymap("n", config.keymaps.add_local_tag, ":Tagonaut local ", { noremap = true })
  vim.api.nvim_set_keymap("n", config.keymaps.add_global_tag, ":Tagonaut global ", { noremap = true })
  vim.api.nvim_set_keymap("n", config.keymaps.symbol_tagging, ":Tagonaut symbol ", { noremap = true })

  vim.api.nvim_create_user_command("Tagonaut", function(opts)
    local args = opts.args
    local tag_type, tag_name = args:match "^(%S+)%s+(.+)$"

    if not tag_type or not tag_name then
      print "Usage: Tagonaut <type> <tag_name>"
      return
    end

    local success, msg
    if tag_type == "local" then
      success, msg = api.add_tag(tag_name, false)
    elseif tag_type == "global" then
      success, msg = api.add_tag(tag_name, true)
    elseif tag_type == "symbol" then
      success, msg = api.add_symbol_tag(tag_name, false, symbols)
    else
      print "Invalid tag type. Use 'local', 'global', or 'symbol'."
      return
    end

    if success then
      print(msg)
      api.update_extmarks()
    else
      print(msg)
    end
  end, {
    nargs = "+",
    complete = function(_, cmdline)
      local args = vim.split(cmdline, "%s+")
      if #args == 2 then
        return { "local", "global", "symbol" }
      end
    end,
  })

  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.list_local_tags,
    ':lua require("tagonaut.telescope").list_local_tags()<CR>',
    { noremap = true, silent = true }
  )
  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.list_all_tags,
    ':lua require("tagonaut.telescope").list_all_tags()<CR>',
    { noremap = true, silent = true }
  )

  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.toggle_extmarks,
    ':lua require("tagonaut.tags").toggle_extmarks()<CR>',
    { noremap = true, silent = true }
  )
  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.trigger_keyed_tag,
    ':lua require("tagonaut.api").trigger_keyed_tag()<CR>',
    { noremap = true, silent = true }
  )
  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.next_tag,
    ':lua require("tagonaut.tags").goto_next_tag(1)<CR>',
    { noremap = true, silent = true }
  )
  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.prev_tag,
    ':lua require("tagonaut.tags").goto_next_tag(-1)<CR>',
    { noremap = true, silent = true }
  )
end

return M



# config.lua

local M = {}

M.options = {
  config_file = vim.fn.expand "~/.nvim/tagonauts.json",
  use_devicons = pcall(require, "nvim-web-devicons"),
  use_telescope = false,
  auto_assign_keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
  use_lsp = true,
  use_treesitter = true,
  extmark = {
    icon = "󱈤",
    hl_group = "ZipTagExtmark",
    fg = nil,
    bg = nil,
    bold = false,
    italic = true,
  },
  keymaps = {
    add_local_tag = "ta",
    add_global_tag = "tA",
    list_local_tags = "tl",
    list_all_tags = "tL",
    toggle_extmarks = "te",
    trigger_keyed_tag = "tt",
    next_tag = "tn",
    prev_tag = "tp",
    symbol_tagging = "ts",
  },
  floating_window = {
    close = "q",
    select = "<CR>",
    delete = "d",
    rename = "r",
    clear = "c",
    assign_key = "a",
    clear_all_keys = "x",
  },
  telescope = {
    select = "<CR>",
    delete = "d",
    rename = "r",
    clear = "c",
    assign_key = "a",
    clear_all_keys = "x",
  },
  keyed_tag_hl_group = "ZipTagKeyedTag",
  deleted_tag_hl_group = "ZipTagDeletedTag",
  extmarks_visible = {},
}

function M.setup(opts)
  opts = opts or {}
  if opts.floating_window then
    opts.floating_window = vim.tbl_deep_extend("force", M.options.floating_window, opts.floating_window)
  end
  if opts.telescope then
    opts.telescope = vim.tbl_deep_extend("force", M.options.telescope, opts.telescope)
  end
  M.options = vim.tbl_deep_extend("force", M.options, opts)
end

return M



# extmarks.lua

local M = {}
local api = vim.api
local config = require("tagonaut.config").options
local utils = require "tagonaut.utils"

local ns_id = api.nvim_create_namespace "tagonaut"
local extmark_ids = {}

function M.setup_highlights()
  api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = M.update_extmark_highlight,
  })

  M.update_extmark_highlight()
end

function M.update_extmark_highlight()
  local fg, bg = utils.get_highlight_colors()

  api.nvim_set_hl(0, config.extmark.hl_group, {
    fg = fg,
    bg = bg,
    bold = config.extmark.bold,
    italic = config.extmark.italic,
  })
end

function M.add_extmark(buf, tag_name, tag_info)
  if not buf or not tag_name or not tag_info then
    print "Error: Invalid arguments for add_extmark"
    return
  end

  local icon = config.extmark.icon
  local hl_group = config.extmark.hl_group

  local line
  if type(tag_info) == "table" then
    if tag_info.type == "symbol" and tag_info.symbol then
      line = tag_info.symbol.range.start.line
    elseif tag_info.line then
      line = tag_info.line - 1
    else
      print "Error: Invalid tag_info structure"
      return
    end
  elseif type(tag_info) == "number" then
    line = tag_info - 1
  else
    print "Error: Unexpected tag_info type"
    return
  end

  local id = api.nvim_buf_set_extmark(buf, ns_id, line, 0, {
    virt_text = { { icon .. " " .. tag_name, hl_group } },
    virt_text_pos = "eol",
  })
  extmark_ids[tag_name] = id
end

function M.remove_extmark(tag_name)
  local buf = api.nvim_get_current_buf()
  if extmark_ids[tag_name] then
    api.nvim_buf_del_extmark(buf, ns_id, extmark_ids[tag_name])
    extmark_ids[tag_name] = nil
  end
end

function M.clear_all_extmarks()
  local buf = api.nvim_get_current_buf()
  api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  extmark_ids = {}
end

function M.update_all_buffers_extmarks(tags)
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(buf) and api.nvim_get_option_value("buflisted", { buf = buf }) then
      M.update_extmarks(buf, tags)
    end
  end
end

function M.update_extmarks(buf, tags)
  buf = buf or api.nvim_get_current_buf()
  local current_file = api.nvim_buf_get_name(buf)

  api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  extmark_ids = {}

  local workspace = vim.fn.getcwd(-1, -1)

  if tags.extmarks_visible[workspace] then
    for tag, info in pairs(tags.workspace[workspace] or {}) do
      if current_file == info.path then
        M.add_extmark(buf, tag, info)
      end
    end

    for tag, info in pairs(tags.global) do
      if current_file == info.path then
        M.add_extmark(buf, tag, info)
      end
    end
  end
end

function M.toggle_extmarks(tags)
  local workspace = vim.fn.getcwd(-1, -1)
  local new_visibility = tags.toggle_extmarks_visibility(workspace)
  if new_visibility then
    M.update_all_buffers_extmarks(tags)
    print "Tags are now visible"
  else
    M.clear_all_extmarks()
    print "Tags are now hidden"
  end
end

return M



# floating.lua

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



# init.lua

local M = {}

function M.setup(opts)
  require("tagonaut.config").setup(opts)
  require("tagonaut.api").load_tags()
  require("tagonaut.extmarks").setup_highlights()
  require("tagonaut.tags").setup_autocmds()
  require("tagonaut.commands").setup()
  if opts.use_lsp then
    require("tagonaut.symbols").setup_rename_hook()
  end
end

return M



# messages.lua

return {
  invalid_tag_info = "Error: Invalid tag information",
  tag_added = function(tag_name, is_global)
    return string.format("Tag '%s' added %s", tag_name, is_global and "globally" or "locally")
  end,
  tag_deleted = function(tag)
    return string.format("Tag '%s' deleted", tag)
  end,
  tags_cleared = function(include_global)
    return include_global and "All tags cleared (including global)." or "All local tags cleared."
  end,
  key_assigned = function(key, tag)
    return string.format("Assigned key [%s] to tag '%s'", key, tag)
  end,
  key_removed = function(key, tag)
    return string.format("Removed key [%s] from tag '%s'", key, tag)
  end,
  key_not_found = function(key)
    return string.format("No tag found for key [%s]", key)
  end,
  all_keys_cleared = "All assigned keys have been cleared.",
  operation_cancelled = "Operation cancelled.",
  confirm_clear_all_tags = "Are you sure you want to clear all tags (including global)? (y/n): ",
  confirm_clear_local_tags = "Are you sure you want to clear all local tags? (y/n): ",
  confirm_clear_all_keys = "Are you sure you want to clear all assigned keys? (y/n): ",
  assign_key_prompt = "Assign key: ",
  jumped_to_tag = function(tag)
    return string.format("Jumped to tag '%s'", tag)
  end,
  tag_not_found = function(tag)
    return string.format("Tag '%s' not found", tag)
  end,
  no_tag_for_key = function(key)
    return string.format("No tag assigned to key '%s'", key)
  end,
  tag_restored = function(tag)
    return string.format("Tag '%s' has been restored", tag)
  end,
  tag_renamed = function(old_tag, new_tag)
    return string.format("Tag '%s' renamed to '%s'", old_tag, new_tag)
  end,
  no_more_tags = "No more tags to navigate to.",
  not_on_tag = "Current cursor position is not on a tag.",
  goto_next_tag = "Go to the next tag.",
  goto_prev_tag = "Go to the prev tag.",
  jumped_to_symbol = function(symbol_name)
    return string.format("Jumped to symbol '%s'", symbol_name)
  end,
  failed_to_jump_to_symbol = function(symbol_name)
    return string.format("Failed to jump to symbol '%s'", symbol_name)
  end,
}



# symbols.lua

local M = {}
local ts_utils = require "nvim-treesitter.ts_utils"
local messages = require "tagonaut.messages"
local api = require "tagonaut.api"

function M.get_symbol_at_cursor()
  local symbol = M.get_lsp_symbol()
  if not symbol then
    symbol = M.get_treesitter_symbol()
  end
  return symbol
end

function M.get_lsp_symbol()
  local params = vim.lsp.util.make_position_params()
  local result = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, 1000)

  if result and result[1] then
    local symbols = result[1].result
    if symbols then
      local cursor_pos = vim.api.nvim_win_get_cursor(0)
      for _, sym in ipairs(symbols) do
        if M.is_cursor_in_range(cursor_pos, sym.range) then
          return {
            name = sym.name,
            kind = sym.kind,
            range = sym.range,
          }
        end
      end
    end
  end
  return nil
end

function M.get_treesitter_symbol()
  local node = ts_utils.get_node_at_cursor()
  if node then
    local start_row, start_col, end_row, end_col = node:range()
    return {
      name = vim.treesitter.get_node_text(node, 0),
      kind = node:type(),
      range = {
        start = { line = start_row, character = start_col },
        ["end"] = { line = end_row, character = end_col },
      },
    }
  end
  return nil
end

function M.is_cursor_in_range(cursor_pos, range)
  local cursor_line, cursor_col = unpack(cursor_pos)
  return (cursor_line >= range.start.line and cursor_line <= range["end"].line)
    and (cursor_col >= range.start.character and cursor_col <= range["end"].character)
end

function M.jump_with_lsp(symbol)
  local params = vim.lsp.util.make_position_params()
  params.position = symbol.range.start

  local result = vim.lsp.buf_request_sync(0, "textDocument/definition", params, 1000)
  if result and result[1] and result[1].result then
    local location = result[1].result[1]
    if location then
      vim.lsp.util.jump_to_location(location, "utf-8")
      return true
    end
  end
  return false
end

function M.jump_to_symbol(symbol, file_path)
  local success = M.jump_with_lsp(symbol)
  if not success then
    success = M.jump_with_treesitter(symbol, file_path)
  end
  if not success then
    vim.api.nvim_win_set_cursor(0, { symbol.range.start.line + 1, symbol.range.start.character })
    success = true
  end

  if success then
    vim.cmd "normal! zz"
    return true, messages.jumped_to_symbol(symbol.name)
  else
    return false, messages.failed_to_jump_to_symbol(symbol.name)
  end
end

function M.jump_to_tag(tag_name, is_global)
  local workspace = M.get_workspace()
  local tag_info = is_global and M.tags.global[tag_name] or M.tags.workspace[workspace][tag_name]

  if not tag_info then
    return false, messages.tag_not_found(tag_name)
  end

  vim.cmd("edit " .. tag_info.path)

  if tag_info.symbol then
    return M.jump_to_symbol(tag_info.symbol)
  elseif tag_info.line then
    vim.api.nvim_win_set_cursor(0, { tag_info.line, 0 })
    vim.cmd "normal! zz"
    return true, messages.jumped_to_tag(tag_name)
  else
    return false, messages.invalid_tag_info
  end
end

function M.get_query_string(symbol)
  local base_query = [[
        (%s name: (identifier) @%s (#eq? @%s "%s"))
    ]]

  local query_types = {
    function_declaration = "function",
    method_declaration = "method",
    class_declaration = "class",
    variable_declaration = "variable",
  }

  local query_type = query_types[symbol.type] or "identifier"
  return string.format(base_query, symbol.type, query_type, query_type, symbol.name)
end

function M.jump_with_treesitter(symbol, file_path)
  local lang = symbol.language or vim.filetype.match { filename = file_path } or "text"
  local parser = vim.treesitter.get_parser(0, lang)
  local tree = parser:parse()[1]

  local query_string = M.get_query_string(symbol)
  local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
  if not ok then
    query_string = [[ ((identifier) @id (#eq? @id "]] .. symbol.name .. [[")) ]]
    query = vim.treesitter.query.parse(lang, query_string)
  end

  local best_match = nil
  local closest_line_diff = math.huge

  for _, node, _ in query:iter_captures(tree:root(), 0) do
    local start_row, start_col, _, _ = node:range()
    local line_diff = math.abs(start_row - symbol.range.start.line)

    if line_diff < closest_line_diff then
      closest_line_diff = line_diff
      best_match = { start_row = start_row, start_col = start_col }
    end
  end

  if best_match then
    vim.api.nvim_win_set_cursor(0, { best_match.start_row + 1, best_match.start_col })
    return true
  end
  return false
end

function M.setup_rename_hook()
  vim.lsp.handlers["textDocument/rename"] = function(err, result, ctx, config)
    vim.lsp.handlers.rename(err, result, ctx, config)
    if not err and result then
      M.update_tags_after_rename(result)
    end
  end
end

function M.update_tags_after_rename(result)
  local changes = result.changes or {}
  for uri, file_changes in pairs(changes) do
    local file_path = vim.uri_to_fname(uri)
    for _, change in ipairs(file_changes) do
      local old_name = vim.fn.fnamemodify(change.oldUri, ":t")
      local new_name = change.newText
      M.update_tags_for_file(file_path, old_name, new_name)
    end
  end
end

function M.update_tags_for_file(file_path, old_name, new_name)
  local updated_tags = {}
  for _, tags in pairs(api.tags) do
    if type(tags) == "table" then
      for tag_name, tag_info in pairs(tags) do
        if tag_info.path == file_path and tag_info.symbol and tag_info.symbol.name == old_name then
          tag_info.symbol.name = new_name
          updated_tags[tag_name] = tag_info
        end
      end
    end
  end

  if next(updated_tags) then
    api.save_tags()
    print(string.format("Updated %d tags after renaming %s to %s", #updated_tags, old_name, new_name))
  end
end

return M



# tags.lua

local M = {}
local api = require "tagonaut.api"
local config = require("tagonaut.config").options
local messages = require "tagonaut.messages"
local extmarks = require "tagonaut.extmarks"

function M.setup_autocmds()
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    callback = function(ev)
      extmarks.update_extmarks(ev.buf, api.tags)
    end,
  })
  vim.api.nvim_set_hl(0, config.keyed_tag_hl_group, {
    fg = "Green",
    bold = true,
    italic = true,
  })
  vim.api.nvim_set_hl(0, config.deleted_tag_hl_group, {
    fg = "Red",
    bold = true,
    italic = true,
  })
end

function M.goto_next_tag(direction)
  local current_file = vim.fn.expand "%:p"
  local current_line = vim.fn.line "."

  local weak_match = nil
  local closest_line_diff = math.huge

  local function check_tags(tags)
    for tag, info in pairs(tags) do
      if info.path == current_file then
        if info.line == current_line then
          return tag
        else
          local line_diff = math.abs(info.line - current_line)
          if line_diff < closest_line_diff then
            weak_match = tag
            closest_line_diff = line_diff
          end
        end
      end
    end
    return nil
  end

  local current_tag = check_tags(api.tags.global)

  if not current_tag then
    local workspace = api.get_workspace()
    if api.tags.workspace[workspace] then
      current_tag = check_tags(api.tags.workspace[workspace])
    end
  end

  if not current_tag and weak_match then
    current_tag = weak_match
  end

  if current_tag then
    local next_tag = api.get_next_tag(current_tag, direction)
    if next_tag then
      vim.cmd("edit " .. next_tag.info.path)
      vim.api.nvim_win_set_cursor(0, { next_tag.info.line, 0 })
      vim.cmd "normal! zz"
      print(messages.jumped_to_tag(next_tag.tag))
    else
      print(messages.no_more_tags)
    end
  else
    local any_tag = next(api.tags.global) or next(api.tags.workspace[api.get_workspace()] or {})
    if any_tag then
      local tag_info = api.tags.global[any_tag] or api.tags.workspace[api.get_workspace()][any_tag]
      vim.cmd("edit " .. tag_info.path)
      vim.api.nvim_win_set_cursor(0, { tag_info.line, 0 })
      vim.cmd "normal! zz"
      print(messages.jumped_to_tag(any_tag))
    else
      print(messages.no_tags_available)
    end
  end
end

return M



# telescope.lua

local M = {}
local api = require "tagonaut.api"
local utils = require "tagonaut.utils"
local config = require("tagonaut.config").options
local messages = require "tagonaut.messages"
local symbols = require "tagonaut.symbols"

local function use_telescope()
  return config.use_telescope and pcall(require, "telescope")
end

local function create_telescope_picker(tag_list, title, include_global)
  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"
  local previewers = require "telescope.previewers"

  local function toggle_key_assignment(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if selection then
      local existing_key = nil
      for key, tag in pairs(api.keyed_tags) do
        if tag == selection.value.tag then
          existing_key = key
          break
        end
      end

      if existing_key then
        local success, msg = api.remove_key_from_tag(existing_key)
        if success then
          print(msg)
          selection.assigned_key = nil
          selection.display = selection.display:gsub(" %[" .. existing_key .. "%]", "")
        end
      else
        vim.ui.input({ prompt = messages.assign_key_prompt }, function(input)
          if input and #input == 1 then
            local success, msg = api.assign_key_to_tag(selection.value.tag, input)
            if success then
              print(msg)
              selection.assigned_key = input
              selection.display = selection.display .. " [" .. input .. "]"
            end
          end
        end)
      end
      local picker = action_state.get_current_picker(prompt_bufnr)
      picker:refresh(picker.finder, { reset_prompt = true })
    end
  end

  local function rename_tag(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if selection then
      vim.ui.input({ prompt = "Enter new tag name: " }, function(new_tag)
        if new_tag and new_tag ~= "" then
          local success, msg = api.rename_tag(selection.value.tag, new_tag, selection.value.type == "global")
          if success then
            print(msg)
            selection.value.tag = new_tag
            selection.ordinal = new_tag
            selection.display = selection.display:gsub(selection.value.tag, new_tag)
            local picker = action_state.get_current_picker(prompt_bufnr)
            picker:refresh(picker.finder, { reset_prompt = true })
          else
            print(msg)
          end
        end
      end)
    end
  end

  local function clear_all_keys(prompt_bufnr)
    vim.ui.input({ prompt = messages.confirm_clear_all_keys }, function(input)
      if input and input:lower() == "y" then
        local success, msg = api.clear_all_keys()
        if success then
          print(msg)
          local picker = action_state.get_current_picker(prompt_bufnr)
          for _, entry in ipairs(picker.finder.results) do
            entry.assigned_key = nil
            entry.display = entry.display:gsub(" %[.%]", "")
          end
          picker:refresh(picker.finder, { reset_prompt = true })
        end
      end
    end)
  end

  local function toggle_delete(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if selection then
      if selection.deleted then
        local success, msg = api.restore_deleted_tag(selection.delete_index)
        if success then
          print(msg)
          selection.deleted = false
          selection.delete_index = nil
          selection.display = selection.display:gsub("~~", "")
        end
      else
        local success, msg = api.delete_tag(selection.value.tag, selection.value.type == "global")
        if success then
          print(msg)
          selection.deleted = true
          selection.delete_index = #api.temp_deleted_tags
          selection.display = "~~" .. selection.display .. "~~"
        end
      end
      local picker = action_state.get_current_picker(prompt_bufnr)
      picker:reset_prompt()
    end
  end

  pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table {
        results = tag_list,
        entry_maker = function(entry)
          local is_directory = vim.fn.isdirectory(entry.path) == 1
          local icon, icon_hl = utils.get_icon(entry.path, is_directory)
          local display = icon .. " " .. entry.tag
          if include_global and entry.type == "global" then
            display = display .. " (G)"
          end
          if entry.symbol then
            display = display .. " [" .. entry.symbol.kind .. "]"
          end
          local assigned_key = nil
          for key, tag in pairs(api.keyed_tags) do
            if tag == entry.tag then
              assigned_key = key
              break
            end
          end
          if assigned_key then
            display = display .. " [" .. assigned_key .. "]"
          end
          local deleted = false
          local delete_index
          for i, deleted_tag in ipairs(api.temp_deleted_tags) do
            if deleted_tag.tag == entry.tag and deleted_tag.is_global == (entry.type == "global") then
              deleted = true
              delete_index = i
              break
            end
          end
          if deleted then
            display = "~~" .. display .. "~~"
          end
          return {
            value = entry,
            display = display,
            ordinal = entry.tag,
            path = entry.path,
            line = entry.line,
            symbol = entry.symbol,
            icon = icon,
            icon_hl = icon_hl,
            assigned_key = assigned_key,
            deleted = deleted,
            delete_index = delete_index,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = previewers.new_buffer_previewer {
        title = "File/Symbol Preview",
        define_preview = function(self, entry)
          local bufnr = self.state.bufnr
          vim.api.nvim_set_option_value("filetype", vim.filetype.match { filename = entry.path }, { buf = bufnr })
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(entry.path))

          if entry.symbol then
            local start_line = entry.symbol.range.start.line
            local end_line = entry.symbol.range["end"].line
            vim.api.nvim_buf_add_highlight(bufnr, -1, "Search", start_line, 0, -1)
            if start_line ~= end_line then
              for i = start_line + 1, end_line do
                vim.api.nvim_buf_add_highlight(bufnr, -1, "Search", i, 0, -1)
              end
            end
          end

          if entry.assigned_key then
            vim.api.nvim_buf_add_highlight(bufnr, -1, config.keyed_tag_hl_group, 0, 0, -1)
          end
          if entry.deleted then
            vim.api.nvim_buf_add_highlight(bufnr, -1, config.deleted_tag_hl_group, 0, 0, -1)
          end
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          if selection and not selection.deleted then
            actions.close(prompt_bufnr)
            local success, msg = api.jump_to_tag(selection.value.tag, selection.value.type == "global", symbols)
            if success then
              print(msg)
            else
              print("Failed to jump to tag: " .. msg)
            end
            local workspace = api.get_workspace()
            vim.cmd("cd " .. workspace)
          else
            print "No selection made or deleted tag selected"
          end
        end)

        map("n", config.telescope.assign_key, function()
          toggle_key_assignment(prompt_bufnr)
          return true
        end)

        map("n", config.telescope.clear_all_keys, function()
          clear_all_keys(prompt_bufnr)
          return true
        end)

        map("n", config.telescope.delete, function()
          toggle_delete(prompt_bufnr)
          return true
        end)

        map("n", config.telescope.rename, function()
          rename_tag(prompt_bufnr)
          return true
        end)

        map("n", config.telescope.clear, function()
          actions.close(prompt_bufnr)
          local prompt = include_global and messages.confirm_clear_all_tags or messages.confirm_clear_local_tags
          vim.ui.input({ prompt = prompt }, function(input)
            if input and input:lower() == "y" then
              local _, _ = api.clear_all_tags(include_global)
            else
              print(messages.operation_cancelled)
            end
          end)
          return true
        end)

        return true
      end,
    })
    :find()
end

local function cleanup_deleted_tags()
  for _, tag_info in ipairs(api.temp_deleted_tags) do
    api.delete_tag(tag_info.tag, tag_info.is_global)
  end
  api.temp_deleted_tags = {}
end

function M.list_local_tags()
  if use_telescope() then
    cleanup_deleted_tags()
    local tag_list = api.list_tags(false)
    create_telescope_picker(tag_list, "Local Tags", false)
  else
    require("tagonaut.floating").list_tags(false)
  end
end

function M.list_all_tags()
  if use_telescope() then
    cleanup_deleted_tags()
    local tag_list = api.list_tags(true)
    create_telescope_picker(tag_list, "All Tags", true)
  else
    require("tagonaut.floating").list_tags(true)
  end
end

return M



# utils.lua

local M = {}
local config = require("tagonaut.config").options

function M.get_highlight_colors()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  local cursorline = vim.api.nvim_get_hl(0, { name = "CursorLine" })

  local fg = config.extmark.fg or (normal.fg and string.format("#%06x", normal.fg) or "NONE")
  local bg = config.extmark.bg or (cursorline.bg and string.format("#%06x", cursorline.bg) or "NONE")
  return fg, bg
end

function M.get_icon(filename, is_directory)
  if config.use_devicons then
    local devicons = require "nvim-web-devicons"
    if is_directory then
      return "", "Directory"
    else
      local icon, icon_highlight = devicons.get_icon(filename, vim.fn.fnamemodify(filename, ":e"), { default = true })
      return icon, icon_highlight
    end
  else
    return is_directory and "" or "", "Normal"
  end
end

return M



# notifications.lua

local M = {}

local function format_message(msg)
  return string.format("[Tagonaut] %s", msg)
end

function M.info(msg)
  vim.notify(format_message(msg), vim.log.levels.INFO)
end

function M.warn(msg)
  vim.notify(format_message(msg), vim.log.levels.WARN)
end

function M.error(msg)
  vim.notify(format_message(msg), vim.log.levels.ERROR)
end

return M



