-- Plugin: LiveMD.nvim
-- Automatically loaded when plugin is loaded

if vim.g.loaded_livemd_nvim then
  return
end
vim.g.loaded_livemd_nvim = true

-- Make health check available
vim.api.nvim_create_user_command('LiveMDCheckHealth', function()
  require('livemd.health').check()
end, {desc = 'Check health of LiveMD plugin'})

-- Set up plugin with defaults
require('livemd').setup({})