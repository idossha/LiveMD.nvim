-- Plugin: LiveMD.nvim
-- Configuration module

local M = {}

-- Configuration with defaults
M.options = {
  port = 8890,
  open_browser = true,
  auto_refresh = true,
  refresh_delay = 300, -- ms
  css_path = nil, -- use default styling
  browser_command = nil, -- auto-detect the default browser
  inactivity_timeout = 5 * 60, -- 5 minutes in seconds
}

-- Apply user settings
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M