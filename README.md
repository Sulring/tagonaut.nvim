# Tagonaut.nvim 🚀

A navigation tool for Neovim that lets you create, manage and quickly jump between tagged locations across your workspaces.

## Screenshots

### Tag Management
![Tag Management](https://raw.githubusercontent.com/Sulring/misc/master/minimal_tags.jpg)
![Tag Management](https://raw.githubusercontent.com/Sulring/misc/master/tags.jpg)

### Workspace Organization
![Workspace Organization](https://raw.githubusercontent.com/Sulring/misc/master/minimal_workspaces.jpg)
![Workspace Organization](https://raw.githubusercontent.com/Sulring/misc/master/workspaces.jpg)

### Quick Trigger
![Quick Trigger](https://raw.githubusercontent.com/Sulring/misc/master/trigger.jpg)

## Heads Up!
This is a bit rough around the edges - made it for my own workflow but sharing in case it's useful to others. LSP symbol tagging is particularly experimental and flaky right now.

## Features
- Tag important code locations
- Quick-jump between tags using shortcuts 
- Workspace organization
- Visual markers in gutter
- Simple search and filtering

## Install

Using lazy.nvim:
```lua
{
  'sulring/tagonaut.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
  },
  config = function()
    require('tagonaut').setup({
      -- optional config
      config_file = vim.fn.stdpath "data" .. "/tagonauts.json",
      use_devicons = pcall(require, "nvim-web-devicons"),
      auto_assign_keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
      use_lsp = true,
      use_treesitter = true,
      show_legend = false,
      minimal = false,
      keymaps = {
        add_tag = "<F5>",
        list_tags = "<leader>l",
        toggle_extmarks = "<F2>",
        trigger_keyed_tag = "<F10>",
        trigger_keyed_file = "<F9>",
        next_tag = "<C-]>",
        prev_tag = "<C-[>",
        symbol_tagging = "ts",
        list_workspaces = "<leader>w",
      },
      workspace_window = {
        close = "q",
        select = "<CR>",
        toggle_ignore = "d",
        rename = "r",
        cycle_sort = "s",
        toggle_show_ignored = "i",
        toggle_legend = "l",
        toggle_minimal = "m",
      },
      taglist_window = {
        close = "q",
        select = "<CR>",
        delete = "d",
        rename = "r",
        clear = "c",
        assign_key = "a",
        clear_all_keys = "x",
        toggle_legend = "l",
        toggle_minimal = "m",
      }
    })
  end
}
```

## Usage
- `<F5>` - Add tag
- `<leader>l` - List tags
- `<F2>` - Toggle markers
- `<F10>` - Jump to tagged location
- `<F9>` - Switch to tagged file 
- `<leader>w` - Manage workspaces
- `j/k,G,gg` - Navigation
- `l` - Toggle legend
- `m` - Toggle minimal mode
## License
MIT

Built as a personal tool but shared with ❤️. Use at your own risk and have fun!
