-- Plugin: nvim-markdown-preview (commands)
-- Register user commands for the plugin

local M = {}

function M.setup()
  -- Check if Python is available
  local python_cmd = ''
  
  if vim.fn.executable('python3') == 1 then
    python_cmd = 'python3'
  elseif vim.fn.executable('python') == 1 then
    python_cmd = 'python'
  else
    vim.notify("Python is required for nvim-markdown-preview but not found. Please install Python 3.", vim.log.levels.ERROR)
    return
  end
  
  -- Check for required Python modules
  local check_modules = vim.fn.system(python_cmd .. " -c \"import http.server\" 2>&1")
  if vim.v.shell_error ~= 0 then
    vim.notify("Python http.server module required for nvim-markdown-preview is missing: " .. check_modules, vim.log.levels.ERROR)
    return
  end
  
  -- Log successful initialization
  vim.notify("nvim-markdown-preview initialized successfully", vim.log.levels.INFO)

  vim.api.nvim_create_user_command(
    'MarkdownPreviewStart',
    function()
      require('nvim-markdown-preview').start_preview()
    end,
    {
      desc = 'Start markdown preview',
      nargs = 0,
    }
  )

  vim.api.nvim_create_user_command(
    'MarkdownPreviewStop',
    function()
      require('nvim-markdown-preview').stop_preview()
    end,
    {
      desc = 'Stop markdown preview',
      nargs = 0,
    }
  )
end

return M