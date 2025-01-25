local M = {}

local api = vim.api
local state = require "tagonaut.taglist.state"
local view = require "tagonaut.taglist.view"
local utils = require "tagonaut.taglist.utils"
local tagonaut_api = require "tagonaut.api"
local messages = require "tagonaut.messages"
local Input = require "nui.input"

local function create_input(opts)
  return Input({
    position = {
      row = opts.row or "50%",
      col = "50%",
    },
    size = {
      width = opts.width or 40,
    },
    border = {
      style = "rounded",
      text = {
        top = opts.title,
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Special",
    },
  }, {
    prompt = opts.prompt or "> ",
    default_value = opts.default_value or "",
    on_submit = opts.on_submit,
    on_close = opts.on_close,
  })
end

function M.move_cursor(delta)
  local current_pos = state.get_cursor_position()
  local new_pos = current_pos + delta
  local tag_list = state.get_current_tag_list()

  if new_pos >= 1 and new_pos <= #tag_list then
    state.set_cursor_position(new_pos)
    if state.get_popup() and state.get_popup().winid then
      vim.api.nvim_win_set_cursor(state.get_popup().winid, { state.get_buffer_line_for_cursor(), 0 })
      M.update_preview(tag_list[new_pos])
    end
  end
end

function M.move_cursor_to(pos)
  local tag_list = state.get_current_tag_list()
  local target_pos = pos
  if pos < 0 then
    target_pos = #tag_list
  end

  state.set_cursor_position(target_pos)
  if state.get_popup() and state.get_popup().winid then
    vim.api.nvim_win_set_cursor(state.get_popup().winid, { state.get_buffer_line_for_cursor(), 0 })
    M.update_preview(tag_list[target_pos])
  end
end

function M.display_tags(workspace_path)
  if state.is_window_open() then
    return
  end

  state.set_current_workspace(workspace_path)
  local workspace = tagonaut_api.workspaces[workspace_path]
  if not workspace or not workspace.tags or next(workspace.tags) == nil then
    vim.notify(messages.no_tags_available, vim.log.levels.INFO)
    return
  end

  local tag_list = utils.get_sorted_tags(workspace.tags)
  state.set_current_tag_list(tag_list)
  state.set_cursor_position(1)

  local popup = view.create_main_popup()
  state.set_popup(popup)

  if state.get_show_preview() then
    local preview = view.create_preview_popup(popup)
    state.set_preview_popup(preview)
    preview:mount()
  end

  popup:mount()
  M.setup_keymaps(popup)

  view.render_content(popup, state)

  if #tag_list > 0 then
    M.update_preview(tag_list[1])
  end

  vim.schedule(function()
    if popup.winid and #tag_list > 0 then
      vim.api.nvim_win_set_cursor(popup.winid, { state.get_buffer_line_for_cursor(), 0 })
    end
  end)
end

function M.setup_keymaps(popup)
  local config = require("tagonaut.config").options.taglist_window

  local mappings = {
    [config.close] = M.close,
    [config.select] = M.select,
    [config.delete] = M.delete,
    [config.clear] = M.clear,
    [config.assign_key] = M.assign_shortcut,
    [config.rename] = M.rename_tag,
    ["/"] = M.toggle_search,
    ["<Esc>"] = M.close,
    ["q"] = M.close,
    ["j"] = function()
      M.move_cursor(1)
    end,
    ["k"] = function()
      M.move_cursor(-1)
    end,
    ["<Down>"] = function()
      M.move_cursor(1)
    end,
    ["<Up>"] = function()
      M.move_cursor(-1)
    end,
    ["gg"] = function()
      M.move_cursor_to(1)
    end,
    ["G"] = function()
      M.move_cursor_to(-1)
    end,
  }

  for key, handler in pairs(mappings) do
    popup:map("n", key, function()
      local cursor = vim.api.nvim_win_get_cursor(popup.winid)
      if state.is_valid_tag_line(cursor[1]) or key == "q" or key == "<Esc>" or key == "/" then
        handler()
      end
    end, { noremap = true, silent = true })
  end

  api.nvim_create_autocmd("CursorMoved", {
    buffer = popup.bufnr,
    callback = function()
      local current_line = vim.api.nvim_win_get_cursor(popup.winid)[1]

      if not state.is_valid_tag_line(current_line) then
        if current_line <= state.HEADER_ROWS then
          vim.api.nvim_win_set_cursor(popup.winid, { state.HEADER_ROWS + 1, 0 })
          return
        end
        local last_tag_line = state.HEADER_ROWS + #state.get_current_tag_list()
        if current_line > last_tag_line then
          vim.api.nvim_win_set_cursor(popup.winid, { last_tag_line, 0 })
          return
        end
      end

      local new_pos = state.buffer_line_to_cursor_position(current_line)
      state.set_cursor_position(new_pos)

      local current_tag = state.get_current_tag()
      if current_tag then
        M.update_preview(current_tag)
      end
    end,
  })
end

function M.update_preview(tag)
  local preview_popup = state.get_preview_popup()
  if preview_popup and tag then
    view.update_preview(preview_popup, tag.info)
  end
end

function M.close()
  local popup = state.get_popup()
  local preview_popup = state.get_preview_popup()

  if preview_popup then
    preview_popup:unmount()
  end
  if popup then
    popup:unmount()
  end

  state.reset()
end

function M.select()
  local tag = state.get_current_tag()
  if not tag then
    vim.notify("No tag selected", vim.log.levels.ERROR)
    return
  end

  if not tag.info or not tag.info.path or not tag.info.line then
    vim.notify("Invalid tag data", vim.log.levels.ERROR)
    return
  end

  M.close()

  local bufnr = vim.fn.bufadd(tag.info.path)
  vim.fn.bufload(bufnr)
  vim.cmd("buffer " .. bufnr)

  vim.api.nvim_win_set_cursor(0, { tag.info.line, 0 })
  vim.cmd "normal! zz"

  vim.notify("Jumped to tag: " .. tag.info.name, vim.log.levels.INFO)
end

function M.delete()
  local tag = state.get_current_tag()
  if not tag then
    return
  end

  local success, msg = tagonaut_api.delete_tag(tag.id)
  if success then
    local workspace = tagonaut_api.workspaces[state.get_current_workspace()]
    local new_tag_list = utils.get_sorted_tags(workspace.tags)
    state.set_current_tag_list(new_tag_list)

    if #new_tag_list > 0 then
      local cursor_pos = math.min(state.get_cursor_position(), #new_tag_list)
      state.set_cursor_position(cursor_pos)
      view.render_content(state.get_popup(), state)
      M.update_preview(new_tag_list[cursor_pos])
    else
      M.close()
    end
  end
  vim.notify(msg, success and vim.log.levels.INFO or vim.log.levels.ERROR)
end

function M.clear()
  create_input({
    title = " Clear Tags ",
    prompt = messages.confirm_clear_tags .. " (y/N): ",
    on_submit = function(value)
      if value and value:lower() == "y" then
        local success, msg = tagonaut_api.clear_all_tags()
        if success then
          M.close()
        end
        vim.notify(msg, success and vim.log.levels.INFO or vim.log.levels.ERROR)
      end
    end,
  }):mount()
end

function M.assign_shortcut()
  local tag = state.get_current_tag()
  if not tag then
    return
  end

  create_input({
    title = " Assign Shortcut ",
    prompt = messages.assign_shortcut_prompt,
    on_submit = function(value)
      if value and value ~= "" then
        local success, msg = tagonaut_api.set_shortcut(tag.id, value)
        if success then
          local workspace = tagonaut_api.workspaces[state.get_current_workspace()]
          local new_tag_list = utils.get_sorted_tags(workspace.tags)
          state.set_current_tag_list(new_tag_list)
          view.render_content(state.get_popup(), state)
        end
        vim.notify(msg, success and vim.log.levels.INFO or vim.log.levels.ERROR)
      end
    end,
  }):mount()
end

function M.rename_tag()
  local tag = state.get_current_tag()
  if not tag then
    return
  end

  create_input({
    title = " Rename Tag ",
    prompt = messages.rename_tag_prompt,
    default_value = tag.info.name,
    on_submit = function(value)
      if value and value ~= "" then
        local success = tagonaut_api.rename_tag(tag.id, value)
        if success then
          M.display_tags(state.get_current_workspace())
        end
      end
    end,
  }):mount()
end

function M.toggle_search()
  create_input({
    title = " Search Tags ",
    prompt = "🔍 ",
    on_submit = function(value)
      state.set_search_query(value or "")
      state.set_search_mode(value and value ~= "")
      view.render_content(state.get_popup(), state)
    end,
  }):mount()
end

function M.list_tags()
  local workspace = tagonaut_api.get_workspace()
  M.display_tags(workspace)
end

return M
