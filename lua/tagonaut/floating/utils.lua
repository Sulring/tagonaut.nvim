local M = {}

function M.format_tag_lines(tag_list)
  local lines = {}
  for _, tag in ipairs(tag_list) do
    local shortcut_text = tag.info.shortcut and (" (" .. tag.info.shortcut .. ")") or ""
    local line = "- " .. tag.info.name .. shortcut_text
    table.insert(lines, line)
  end
  return lines
end

function M.apply_highlights(buffer, lines)
  local ns_id = vim.api.nvim_create_namespace("TagonautHighlight")
  vim.api.nvim_buf_clear_namespace(buffer, ns_id, 0, -1)

  for i, line in ipairs(lines) do
    local name_start = 2
    local name_end = line:find(" %(") or #line
    local shortcut_start = line:find(" %(")
    local shortcut_end = line:find("%)")

    vim.api.nvim_buf_add_highlight(buffer, ns_id, "Identifier", i - 1, name_start, name_end)
    if shortcut_start and shortcut_end then
      vim.api.nvim_buf_add_highlight(buffer, ns_id, "Special", i - 1, shortcut_start, shortcut_end + 1)
    end
  end
end

function M.get_sorted_tags(tags)
  local tag_list = {}
  for id, info in pairs(tags) do
    table.insert(tag_list, { id = id, info = info })
  end
  table.sort(tag_list, function(a, b)
    return a.info.name < b.info.name
  end)
  return tag_list
end

return M
