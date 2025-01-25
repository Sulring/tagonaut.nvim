local M = {}
local api = vim.api
local config = require("tagonaut.config").options

local ns_id = api.nvim_create_namespace "tagonaut"
local extmark_ids = {}

--- Setup highlight groups for extmarks
function M.setup_highlights()
  api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = M.update_extmark_highlight,
  })
  M.update_extmark_highlight()
end

--- Update extmark highlight colors
function M.update_extmark_highlight()
  local fg, bg = require("tagonaut.utils").get_highlight_colors()
  api.nvim_set_hl(0, config.extmark.hl_group, {
    fg = fg,
    bg = bg,
    bold = config.extmark.bold,
    italic = config.extmark.italic,
  })
end

--- Add an extmark for a tag
--- @param buf number: Buffer handle
--- @param tag_id number: Tag identifier
--- @param tag_info table: Tag information
function M.add_extmark(buf, tag_id, tag_info)
  if not buf or not tag_id or not tag_info then
    return
  end

  local icon = config.extmark.icon
  local hl_group = config.extmark.hl_group

  local line
  if tag_info.symbol then
    line = tag_info.symbol.range.start.line
  elseif tag_info.line then
    line = tag_info.line - 1
  else
    return
  end

  local display_text = tag_info.name
  if tag_info.shortcut then
    display_text = string.format("[%s] %s", tag_info.shortcut, tag_info.name)
  end

  local id = api.nvim_buf_set_extmark(buf, ns_id, line, 0, {
    virt_text = { { icon .. " " .. display_text, hl_group } },
    virt_text_pos = "eol",
  })
  extmark_ids[tag_id] = id
end

--- Remove an extmark
--- @param tag_id number: The ID of the tag whose extmark should be removed
function M.remove_extmark(tag_id)
  local buf = api.nvim_get_current_buf()
  if extmark_ids[tag_id] then
    pcall(api.nvim_buf_del_extmark, buf, ns_id, extmark_ids[tag_id])
    extmark_ids[tag_id] = nil
  end
end

--- Clear all extmarks from the current buffer
function M.clear_all_extmarks()
  local buf = api.nvim_get_current_buf()
  api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  extmark_ids = {}
end

--- Update extmarks for a buffer
--- @param buf number: Buffer handle
--- @param workspace_data table: Workspace data containing tags
function M.update_extmarks(buf, workspace_data)
  if not buf or not workspace_data then
    return
  end

  if not workspace_data.extmarks_visible then
    return
  end

  local current_file = api.nvim_buf_get_name(buf)
  api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  extmark_ids = {}

  for tag_id, tag_info in pairs(workspace_data.tags) do
    if tag_info.path == current_file then
      M.add_extmark(buf, tag_id, tag_info)
    end
  end
end

--- Update a single tag's extmark
--- @param tag_id number: The ID of the tag to update
--- @param tag_info table: The tag information
function M.update_tag_extmark(tag_id, tag_info)
  local buf = vim.fn.bufnr(tag_info.path)
  if buf ~= -1 and api.nvim_buf_is_loaded(buf) then
    if extmark_ids[tag_id] then
      M.remove_extmark(tag_id)
    end
    M.add_extmark(buf, tag_id, tag_info)
  end
end

--- Get extmark position for a tag
--- @param tag_id number: The ID of the tag
--- @return table|nil: Position information if found
function M.get_extmark_position(tag_id)
  local buf = api.nvim_get_current_buf()
  if extmark_ids[tag_id] then
    local pos = api.nvim_buf_get_extmark_by_id(buf, ns_id, extmark_ids[tag_id], {})
    if pos and #pos == 2 then
      return { line = pos[1], col = pos[2] }
    end
  end
  return nil
end

return M
