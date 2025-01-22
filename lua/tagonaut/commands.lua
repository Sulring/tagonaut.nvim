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
  vim.api.nvim_set_keymap(
    "n",
    config.keymaps.trigger_keyed_file,
    ':lua require("tagonaut.api").trigger_keyed_file()<CR>',
    { noremap = true, silent = true }
  )
end

return M
