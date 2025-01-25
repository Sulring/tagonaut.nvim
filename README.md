# Tagonaut.nvim 🚀

A navigation tool for Neovim that lets you create, manage and quickly jump between tagged locations across your workspaces. Think of it as dropping pins on a code map!

## Screenshots

### Tag Management
![Tag Management](https://sulring.fra1.cdn.digitaloceanspaces.com/tagonaut/tags.jpg)

### Workspace Organization
![Workspace Organization](https://sulring.fra1.cdn.digitaloceanspaces.com/tagonaut/workspaces.jpg)

### Quick Trigger
![Quick Trigger](https://sulring.fra1.cdn.digitaloceanspaces.com/tagonaut/trigger.jpg)

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
  'your-username/tagonaut.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
  },
  config = function()
    require('tagonaut').setup({
      -- optional config
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

## License
MIT

Built as a personal tool but shared with ❤️. Use at your own risk and have fun!
