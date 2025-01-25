local M = {}
local config = require("tagonaut.config").options
local api = require "tagonaut.api"
local symbols = require "tagonaut.symbols"

function M.setup()
  vim.api.nvim_set_keymap("n", config.keymaps.add_tag, ":Tagonaut tag ", { noremap = true })
  vim.api.nvim_set_keymap("n", config.keymaps.symbol_tagging, ":Tagonaut symbol ", { noremap = true })

  vim.api.nvim_create_user_command("Tagonaut", function(opts)
    local args = opts.args
    local tag_type, tag_name = args:match "^(%S+)%s+(.+)$"

    if not tag_type or not tag_name then
      print "Usage: Tagonaut <type> <tag_name>"
      return
    end

    local success, msg
    if tag_type == "tag" then
      success, msg = api.add_tag(tag_name)
    elseif tag_type == "symbol" then
      success, msg = api.add_symbol_tag(tag_name, symbols)
    else
      print "Invalid tag type. Use 'tag' or 'symbol'"
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
        return { "tag", "symbol" }
      end

      local workspace = api.get_workspace()
      if api.workspaces[workspace] and api.workspaces[workspace].tags then
        local suggestions = {}
        for _, info in pairs(api.workspaces[workspace].tags) do
          table.insert(suggestions, info.name)
        end
        return suggestions
      end
      return {}
    end,
  })

  vim.api.nvim_create_user_command("TagonautList", function()
    require("tagonaut.floating.init").list_tags()
  end, {})

  vim.api.nvim_create_user_command("TagonautToggle", function()
    require("tagonaut.tags").toggle_extmarks()
  end, {})

  vim.api.nvim_create_user_command("TagonautJump", function(opts)
    local tag_name = opts.args
    if not tag_name or tag_name == "" then
      print "Usage: TagonautJump <tag_name>"
      return
    end

    local workspace = api.get_workspace()
    local tag_id
    if api.workspaces[workspace] and api.workspaces[workspace].tags then
      for id, info in pairs(api.workspaces[workspace].tags) do
        if info.name == tag_name then
          tag_id = id
          break
        end
      end
    end

    if tag_id then
      local success, msg = api.jump_to_tag(tag_id, symbols)
      print(msg)
    else
      print("Tag '" .. tag_name .. "' not found")
    end
  end, {
    nargs = 1,
    complete = function()
      local workspace = api.get_workspace()
      if api.workspaces[workspace] and api.workspaces[workspace].tags then
        local suggestions = {}
        for _, info in pairs(api.workspaces[workspace].tags) do
          table.insert(suggestions, info.name)
        end
        return suggestions
      end
      return {}
    end,
  })

  vim.api.nvim_create_user_command("TagonautShortcut", function(opts)
    local args = vim.split(opts.args, "%s+")
    if #args ~= 2 then
      print "Usage: TagonautShortcut <tag_name> <shortcut>"
      return
    end

    local tag_name, shortcut = args[1], args[2]

    local workspace = api.get_workspace()
    local tag_id
    if api.workspaces[workspace] and api.workspaces[workspace].tags then
      for id, info in pairs(api.workspaces[workspace].tags) do
        if info.name == tag_name then
          tag_id = id
          break
        end
      end
    end

    if tag_id then
      local success, msg = api.set_shortcut(tag_id, shortcut)
      print(msg)
      if success then
        api.update_extmarks()
      end
    else
      print("Tag '" .. tag_name .. "' not found")
    end
  end, {
    nargs = "+",
    complete = function(arglead, cmdline)
      local args = vim.split(cmdline, "%s+")
      if #args == 2 then
        local workspace = api.get_workspace()
        if api.workspaces[workspace] and api.workspaces[workspace].tags then
          local suggestions = {}
          for _, info in pairs(api.workspaces[workspace].tags) do
            table.insert(suggestions, info.name)
          end
          return suggestions
        end
      end
      return {}
    end,
  })

  vim.api.nvim_create_user_command("TagonautWorkspace", function(opts)
    local args = vim.split(opts.args, "%s+")
    local cmd = args[1]

    if cmd == "switch" and args[2] then
      require("tagonaut.workspace").switch_workspace(args[2])
    elseif cmd == "list" then
      print "Workspaces:"
      for _, ws in ipairs(require("tagonaut.workspace").get_workspaces_list()) do
        print(string.format("%s (%d tags)", ws.path, ws.tag_count))
      end
    else
      require("tagonaut.workspace").open_workspace_window()
    end
  end, {
    nargs = "*",
    complete = function(_, cmdline)
      local args = vim.split(cmdline, "%s+")
      if #args == 2 then
        return { "switch", "list" }
      elseif args[1] == "switch" then
        return vim.fn.glob(args[2] .. "*", false, true)
      end
      return {}
    end,
  })

  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.list_tags,
    ':lua require("tagonaut.floating.init").list_tags()<CR>',
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

  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.trigger_keyed_file,
    ':lua require("tagonaut.api").trigger_keyed_file()<CR>',
    { noremap = true, silent = true }
  )
  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.list_workspaces,
    ':lua require("tagonaut.workspace").open_workspace_window()<CR>',
    { noremap = true, silent = true }
  )
end

return M
