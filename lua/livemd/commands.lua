-- Plugin: LiveMD.nvim
-- Commands module

local M = {}

-- Register plugin commands
function M.setup()
  vim.api.nvim_create_user_command(
    'LiveMDStart',
    function()
      require('livemd').start_preview()
    end,
    {
      desc = 'Start LiveMD preview',
      nargs = 0,
    }
  )

  vim.api.nvim_create_user_command(
    'LiveMDStop',
    function()
      require('livemd').stop_preview()
    end,
    {
      desc = 'Stop LiveMD preview',
      nargs = 0,
    }
  )
end

return M