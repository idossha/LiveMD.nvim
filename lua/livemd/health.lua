-- Plugin: LiveMD.nvim
-- Health check module

local M = {}

function M.check()
  -- Create health report
  local health = vim.health or require('health')
  local start = health.start or health.report_start
  local ok = health.ok or health.report_ok
  local warn = health.warn or health.report_warn
  local error = health.error or health.report_error
  
  start("LiveMD.nvim")

  -- Check Neovim version
  if vim.fn.has('nvim-0.5.0') == 1 then
    ok("Neovim version >= 0.5.0")
  else
    error("Neovim version must be >= 0.5.0")
  end

  -- Check Python availability
  local python_cmd = nil
  if vim.fn.executable('python3') == 1 then
    python_cmd = 'python3'
    ok("Python 3 found")
  elseif vim.fn.executable('python') == 1 then
    python_cmd = 'python'
    ok("Python found")
  else
    error("Python is required but not found. Please install Python 3.")
    return
  end

  -- Check for required Python modules
  local check_modules = vim.fn.system(python_cmd .. " -c \"import http.server\" 2>&1")
  if vim.v.shell_error ~= 0 then
    error("Python http.server module is missing: " .. check_modules)
  else
    ok("Python http.server module found")
  end
end

return M