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
