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
  cursor_line = cursor_line - 1
  return cursor_line >= range.start.line
    and cursor_line <= range["end"].line
    and cursor_col >= range.start.character
    and cursor_col <= range["end"].character
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
  local workspace = api.get_workspace()
  local updated = false

  if api.workspaces[workspace] and api.workspaces[workspace].tags then
    for tag_id, tag_info in pairs(api.workspaces[workspace].tags) do
      if tag_info.path == file_path and tag_info.symbol and tag_info.symbol.name == old_name then
        tag_info.symbol.name = new_name
        updated = true
      end
    end
  end

  if updated then
    api.save_tags()
    print(string.format("Updated tags after renaming %s to %s", old_name, new_name))
  end
end

function M.find_symbol_tags(symbol_name)
  local workspace = api.get_workspace()
  local found_tags = {}

  if api.workspaces[workspace] and api.workspaces[workspace].tags then
    for tag_id, tag_info in pairs(api.workspaces[workspace].tags) do
      if tag_info.symbol and tag_info.symbol.name == symbol_name then
        table.insert(found_tags, {
          id = tag_id,
          info = tag_info,
        })
      end
    end
  end

  return found_tags
end

function M.update_symbol_references(old_name, new_name)
  local workspace = api.get_workspace()
  local updated = false

  if api.workspaces[workspace] and api.workspaces[workspace].tags then
    for tag_id, tag_info in pairs(api.workspaces[workspace].tags) do
      if tag_info.symbol and tag_info.symbol.name == old_name then
        tag_info.symbol.name = new_name
        updated = true
      end
    end
  end

  if updated then
    api.save_tags()
    print(string.format("Updated symbol references from %s to %s", old_name, new_name))
  end
end

return M
