-- Plugin: LiveMD.nvim
-- UI components module

local M = {}

-- Show buffer switch prompt
function M.show_switch_prompt(current_buffer, new_buffer, on_switch)
  local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(new_buffer), ":t")
  local current_buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(current_buffer), ":t")
  
  -- Create a floating window with the question
  local width = 60
  local height = 6
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer content with clearer instructions
  local lines = {
    "Switch LiveMD preview to: " .. buf_name .. "?",
    "",
    "Press Y to switch preview",
    "Press N or ESC to cancel",
    "",
    "Current preview: " .. current_buf_name
  }
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, lines)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(prompt_buf, 'modifiable', false)
  
  -- Calculate position (center of the screen)
  local ui = vim.api.nvim_list_uis()[1]
  local win_width = ui.width
  local win_height = ui.height
  
  local win = vim.api.nvim_open_win(prompt_buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((win_width - width) / 2),
    row = math.floor((win_height - height) / 2),
    style = 'minimal',
    border = 'rounded'
  })
  
  -- Set window options
  vim.api.nvim_win_set_option(win, 'winblend', 15)
  
  -- Set key mappings for the prompt
  local opts = { noremap = true, silent = true, buffer = prompt_buf }
  vim.keymap.set('n', 'y', function()
    -- User selected Yes - switch to the new buffer
    on_switch(new_buffer)
    vim.api.nvim_win_close(win, true)
    vim.notify("Switched preview to: " .. buf_name, vim.log.levels.INFO)
  end, opts)
  
  vim.keymap.set('n', 'n', function()
    -- User selected No - close the prompt only
    vim.api.nvim_win_close(win, true)
    vim.notify("Kept existing preview", vim.log.levels.INFO)
  end, opts)
  
  -- Close on Escape key
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
    vim.notify("Cancelled", vim.log.levels.INFO)
  end, opts)
end

return M