# LiveMD.nvim

A lightweight, fast Markdown preview plugin for NeoVim that renders your Markdown files in a browser with live updates.

## Features

- 🚀 Lightweight implementation with minimal dependencies
- 🔄 Live preview with automatic refresh on changes
- 🌐 Preview in your default browser
- 🎨 Clean, GitHub-like styling with syntax highlighting
- 🛠️ Configurable options

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- Add to your lazy.nvim configuration
{
  "idohaber/LiveMD.nvim",
  ft = {"markdown", "md"},
  cmd = {"LiveMDStart", "LiveMDStop"},
  config = true,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'idohaber/LiveMD.nvim',
  config = function()
    require('livemd').setup()
  end,
  ft = {'markdown', 'md'}
}
```

### Manual Installation

Clone the repository into your NeoVim plugins directory:

```bash
git clone https://github.com/idohaber/LiveMD.nvim.git ~/.local/share/nvim/site/pack/plugins/start/LiveMD.nvim
```

## Usage

### Commands

- `:LiveMDStart` - Start the preview server and open browser
- `:LiveMDStop` - Stop the preview server

### Configuration

You can configure the plugin by passing options to the setup function:

```lua
require('livemd').setup({
  port = 8890,              -- Port to run the preview server on
  open_browser = true,      -- Automatically open browser when starting preview
  auto_refresh = true,      -- Automatically refresh preview on changes
  refresh_delay = 300,      -- Delay in ms between refreshes
  css_path = nil,           -- Custom CSS file path (nil for default styling)
  browser_command = nil,    -- Custom browser command (nil for system default)
  inactivity_timeout = 300, -- Close preview after 5 minutes of inactivity
})
```

### Keymappings

Add these to your configuration to set up keymappings:

```lua
-- Using <leader>lm prefix for LiveMD
vim.api.nvim_set_keymap('n', '<leader>lms', ':LiveMDStart<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<leader>lmx', ':LiveMDStop<CR>', { noremap = true, silent = true })
```

## Requirements

- NeoVim 0.5.0+
- Python 3 (with http.server module)

## How It Works

This plugin takes a simple but effective approach to Markdown previewing:

1. Generates HTML directly in Lua with the Marked.js library
2. Saves the HTML to a temporary file
3. Starts a Python HTTP server in that directory
4. Opens your default browser to view the HTML
5. Auto-refreshes the view when you make changes
6. Shows a popup when trying to preview a different markdown file
7. Automatically closes the preview after 5 minutes of inactivity

This approach is reliable and works on all platforms with minimal dependencies.

## Customization

### Custom Browser

Specify a custom browser command:

```lua
require('livemd').setup({
  browser_command = 'firefox',  -- or 'chrome', 'brave', etc.
})
```

## Troubleshooting

If you encounter issues:

1. Check if the port (default: 8890) is already in use
2. Ensure Python 3 is installed and available in your PATH
3. Check NeoVim logs with `:messages`

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.