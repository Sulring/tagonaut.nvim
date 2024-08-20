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
