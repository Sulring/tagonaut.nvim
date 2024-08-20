local M = {}

local function format_message(msg)
  return string.format("[Tagonaut] %s", msg)
end

function M.info(msg)
  vim.notify(format_message(msg), vim.log.levels.INFO)
end

function M.warn(msg)
  vim.notify(format_message(msg), vim.log.levels.WARN)
end

function M.error(msg)
  vim.notify(format_message(msg), vim.log.levels.ERROR)
end

return M
