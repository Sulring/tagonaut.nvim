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
