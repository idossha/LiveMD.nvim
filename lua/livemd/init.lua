-- Plugin: LiveMD.nvim
-- A lightweight markdown preview plugin for NeoVim
-- Main entry module

local M = {}

-- Load submodules
local config = require('livemd.config')
local utils = require('livemd.utils')
local server = require('livemd.server')
local ui = require('livemd.ui')
local commands = require('livemd.commands')
local autocmds = require('livemd.autocmds')
local health = require('livemd.health')

-- Initialize the plugin
function M.setup(opts)
  -- Apply user configuration
  config.setup(opts)
  
  -- Register commands
  commands.setup()
  
  -- Setup autocommands
  autocmds.setup(config, utils, server)
  
  -- Check if Python is available
  local python_cmd = ''
  
  if vim.fn.executable('python3') == 1 then
    python_cmd = 'python3'
  elseif vim.fn.executable('python') == 1 then
    python_cmd = 'python'
  else
    vim.notify("Python is required for LiveMD.nvim but not found. Please install Python 3.", vim.log.levels.ERROR)
    return
  end
  
  -- Check for required Python modules
  local check_modules = vim.fn.system(python_cmd .. " -c \"import http.server\" 2>&1")
  if vim.v.shell_error ~= 0 then
    vim.notify("Python http.server module required for LiveMD.nvim is missing: " .. check_modules, vim.log.levels.ERROR)
    return
  end
  
  -- Log successful initialization
  vim.notify("LiveMD.nvim initialized successfully", vim.log.levels.INFO)
end

-- Start preview of current buffer
function M.start_preview()
  -- Get the current buffer ID
  local buf = vim.api.nvim_get_current_buf()
  local file_type = vim.bo[buf].filetype
  
  -- Check if the buffer is a markdown file
  if file_type ~= "markdown" and file_type ~= "md" then
    vim.notify("Current buffer is not a markdown file", vim.log.levels.WARN)
    return
  end
  
  -- If a server is already running
  if server.is_server_running() then
    -- If different buffer, prompt to switch
    if buf ~= utils.get_buffer() then
      -- Show the buffer switch prompt
      ui.show_switch_prompt(utils.get_buffer(), buf, function(new_buf)
        utils.set_buffer(new_buf)
        server.update_preview()
        utils.reset_inactivity_timer(config, M.stop_preview)
      end)
      return
    else
      -- Already previewing this buffer
      vim.notify("Already previewing current buffer", vim.log.levels.INFO)
      return
    end
  end
  
  -- Set current buffer
  utils.set_buffer(buf)
  
  -- Start the server
  if not server.start_server() then
    return
  end
  
  -- Update the preview content
  server.update_preview()
  
  -- Open browser if configured
  if config.options.open_browser then
    server.open_browser()
  end
  
  -- Start inactivity timer
  utils.reset_inactivity_timer(config, M.stop_preview)
end

-- Stop the preview
function M.stop_preview()
  server.stop_server()
  utils.reset_state()
end

-- Check if preview is active for the current buffer
function M.is_preview_active()
  return server.is_server_running() and utils.is_buffer_active()
end

-- Register health check for :checkhealth
-- This will be available as :checkhealth livemd if supported
if vim.health then
  M.health = health
  
  -- For older versions of Neovim
  if vim.fn.exists(':checkhealth') == 2 then
    vim.cmd([[
      augroup LiveMD_Health
        autocmd!
        autocmd User NeovimHealthStart lua require('livemd.health').check()
      augroup END
    ]])
  end
end

return M