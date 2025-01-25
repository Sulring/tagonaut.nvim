local M = {}
local config = require("tagonaut.config").options

function M.get_sorted_tags(tags)
  local tag_list = {}
  for id, info in pairs(tags) do
    table.insert(tag_list, {
      id = id,
      info = info,
    })
  end

  table.sort(tag_list, function(a, b)
    if a.info.shortcut and b.info.shortcut then
      return a.info.shortcut < b.info.shortcut
    elseif a.info.shortcut then
      return true
    elseif b.info.shortcut then
      return false
    else
      return a.info.name < b.info.name
    end
  end)

  return tag_list
end

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
