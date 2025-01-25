local M = {}

function M.setup(opts)
  require("tagonaut.config").setup(opts)
  require("tagonaut.api").load_tags()
  require("tagonaut.api").set_workspace(vim.fn.getcwd())
  require("tagonaut.extmarks").setup_highlights()
  require("tagonaut.tags").setup_autocmds()
  require("tagonaut.commands").setup()
  if opts.use_lsp then
    require("tagonaut.symbols").setup_rename_hook()
  end
end

return M
