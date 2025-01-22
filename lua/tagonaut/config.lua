local M = {}

M.options = {
  config_file = vim.fn.expand "~/.nvim/tagonauts.json",
  use_devicons = pcall(require, "nvim-web-devicons"),
  use_telescope = false,
  auto_assign_keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
  use_lsp = true,
  use_treesitter = true,
  extmark = {
    icon = "󱈤",
    hl_group = "ZipTagExtmark",
    fg = nil,
    bg = nil,
    bold = false,
    italic = true,
  },
  keymaps = {
    add_local_tag = "<F5>",
    add_global_tag = "<F6>",
    list_local_tags = "<leader>l",
    list_all_tags = "<F1>",
    toggle_extmarks = "<F2>",
    trigger_keyed_tag = "<F10>",
    trigger_keyed_file = "<F9>",
    next_tag = "<C-]>",
    prev_tag = "<C-[>",
    symbol_tagging = "ts",
  },
  floating_window = {
    close = "q",
    select = "<CR>",
    delete = "d",
    rename = "r",
    clear = "c",
    assign_key = "a",
    clear_all_keys = "x",
  },
  telescope = {
    select = "<CR>",
    delete = "d",
    rename = "r",
    clear = "c",
    assign_key = "a",
    clear_all_keys = "x",
  },
  keyed_tag_hl_group = "ZipTagKeyedTag",
  deleted_tag_hl_group = "ZipTagDeletedTag",
  extmarks_visible = {},
}

function M.setup(opts)
  opts = opts or {}
  if opts.floating_window then
    opts.floating_window = vim.tbl_deep_extend("force", M.options.floating_window, opts.floating_window)
  end
  if opts.telescope then
    opts.telescope = vim.tbl_deep_extend("force", M.options.telescope, opts.telescope)
  end
  M.options = vim.tbl_deep_extend("force", M.options, opts)
end

return M
