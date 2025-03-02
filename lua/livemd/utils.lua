-- Plugin: LiveMD.nvim
-- Utility functions module

local M = {}

-- State variables
local current_buffer = nil
local last_update_time = 0
local inactivity_timer_id = nil

-- Set current buffer
function M.set_buffer(buf)
  current_buffer = buf
end

-- Get current buffer
function M.get_buffer()
  return current_buffer
end

-- Get the buffer content
function M.get_buffer_content()
  -- Get content from the buffer being previewed, not necessarily the current buffer
  if not current_buffer then
    return ""
  end
  
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(current_buffer) then
    vim.notify("Preview buffer no longer exists", vim.log.levels.WARN)
    return ""
  end
  
  local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, -1, false)
  return table.concat(lines, "\n")
end

-- Check if the buffer is valid
function M.is_buffer_valid()
  return current_buffer and vim.api.nvim_buf_is_valid(current_buffer)
end

-- Buffer is active
function M.is_buffer_active()
  return current_buffer == vim.api.nvim_get_current_buf()
end

-- Reset the inactivity timer
function M.reset_inactivity_timer(config, stop_preview_fn)
  -- Clear existing timer
  if inactivity_timer_id then
    vim.fn.timer_stop(inactivity_timer_id)
    inactivity_timer_id = nil
  end
  
  -- Set new timer (convert seconds to milliseconds)
  inactivity_timer_id = vim.fn.timer_start(config.options.inactivity_timeout * 1000, function()
    vim.schedule(function()
      if M.is_buffer_valid() then
        vim.notify("Markdown preview closed due to inactivity (" .. 
          config.options.inactivity_timeout .. " seconds)", vim.log.levels.INFO)
        stop_preview_fn()
      end
    end)
  end)
end

-- Stop the inactivity timer
function M.stop_inactivity_timer()
  if inactivity_timer_id then
    vim.fn.timer_stop(inactivity_timer_id)
    inactivity_timer_id = nil
  end
end

-- Update last refresh time
function M.update_refresh_time()
  last_update_time = vim.loop.now()
end

-- Check if refresh is needed based on delay
function M.should_refresh(config)
  local current_time = vim.loop.now()
  return current_time - last_update_time > config.options.refresh_delay
end

-- Reset all state
function M.reset_state()
  current_buffer = nil
  last_update_time = 0
  M.stop_inactivity_timer()
end

return M