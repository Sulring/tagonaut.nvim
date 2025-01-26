local M = {}

M.options = {
  config_file = vim.fn.stdpath "data" .. "/tagonauts.json",
  use_devicons = pcall(require, "nvim-web-devicons"),
  auto_assign_keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
  use_lsp = true,
  use_treesitter = true,
  show_legend = true,
  minimal = false,
  minimal_mode_state = nil,
  extmark = {
    icon = "󱈤",
    hl_group = "ZipTagExtmark",
    fg = nil,
    bg = nil,
    bold = false,
    italic = true,
  },
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
  },
  keyed_tag_hl_group = "ZipTagKeyedTag",
  deleted_tag_hl_group = "ZipTagDeletedTag",
  extmarks_visible = {},
}

function M.setup(opts)
  opts = opts or {}
  opts.taglist_window = opts.taglist_window or {}
  opts.workspace_window = opts.workspace_window or {}
  opts.taglist_window = vim.tbl_deep_extend("force", M.options.taglist_window, opts.taglist_window)
  opts.workspace_window = vim.tbl_deep_extend("force", M.options.workspace_window, opts.workspace_window)
  M.options = vim.tbl_deep_extend("force", M.options, opts)
end

return M
