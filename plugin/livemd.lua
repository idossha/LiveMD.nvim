-- Plugin: LiveMD.nvim
-- Automatically loaded when plugin is loaded

if vim.g.loaded_livemd_nvim then
  return
end
vim.g.loaded_livemd_nvim = true

-- Set up plugin with defaults
require('livemd').setup({})