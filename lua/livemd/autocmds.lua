-- Plugin: LiveMD.nvim
-- Autocommands module

local M = {}

-- Setup autocommands
function M.setup(config, utils, server)
  -- Create autocommands for markdown files
  vim.api.nvim_create_augroup("LiveMD", { clear = true })
  
  -- Auto-update preview when text changes
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "BufWritePost"}, {
    group = "LiveMD",
    pattern = {"*.md", "*.markdown"},
    callback = function()
      local current_buf = vim.api.nvim_get_current_buf()
      
      -- Only update if this buffer is the current preview target
      if current_buf == utils.get_buffer() and config.options.auto_refresh then
        if utils.should_refresh(config) then
          utils.update_refresh_time()
          server.update_preview()
          utils.reset_inactivity_timer(config, require('livemd').stop_preview)
        end
      end
    end
  })
  
  -- Reset inactivity timer on cursor movements in the preview buffer
  vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
    group = "LiveMD",
    callback = function()
      local current_buf = vim.api.nvim_get_current_buf()
      if current_buf == utils.get_buffer() and server.is_server_running() then
        utils.reset_inactivity_timer(config, require('livemd').stop_preview)
      end
    end
  })
  
  -- Clean up when leaving Neovim
  vim.api.nvim_create_autocmd("VimLeave", {
    group = "LiveMD",
    callback = function()
      require('livemd').stop_preview()
    end
  })
end

return M