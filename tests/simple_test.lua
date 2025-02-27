-- Simple test file for nvim-markdown-preview
-- This file contains the most basic tests to verify core functionality
-- This is designed to run standalone without any test framework dependencies

-- Create mock vim global
_G.vim = {
  api = {
    nvim_create_augroup = function() return 1 end,
    nvim_create_autocmd = function() return 1 end,
    nvim_buf_get_lines = function() return {"# Test Markdown", "", "This is a test."} end,
    nvim_get_current_buf = function() return 1 end,
    nvim_create_user_command = function() end
  },
  fn = {
    tempname = function() return "/tmp/mock_tempdir" end,
    mkdir = function() return 1 end,
    exepath = function(cmd) 
      if cmd == "python3" then return "/usr/bin/python3" end
      return ""
    end,
    has = function() return 1 end,
    executable = function() return 1 end,
    json_decode = function(str) return {status = "started", port = 8890} end,
    jobstart = function() return 999 end,
    jobstop = function() return 0 end,
    delete = function() return 0 end,
    fnamemodify = function(path, mod) return path end,
    filereadable = function() return 1 end,
    system = function() return "" end
  },
  loop = {
    now = function() return 12345 end,
    sleep = function() end,
    new_pipe = function() return {close = function() end, read_start = function() end} end,
    spawn = function()
      local handle = {close = function() end}
      return handle, 999
    end
  },
  notify = function() end,
  bo = {[1] = {filetype = "markdown"}},
  g = {},
  schedule = function(cb) cb() end,
  defer_fn = function(cb, _) cb() end,
  tbl_deep_extend = function(_, t1, t2) 
    local result = {}
    for k, v in pairs(t1) do result[k] = v end
    for k, v in pairs(t2) do result[k] = v end
    return result
  end,
  log = {
    levels = {
      ERROR = 1,
      WARN = 2,
      INFO = 3
    }
  },
  v = { shell_error = 0 }
}

-- Mock io.open
local old_io_open = io.open
io.open = function()
  return {
    write = function() return true end,
    close = function() return true end
  }
end

-- Add parent directory to package path
package.path = package.path .. ";../lua/?.lua;../lua/?/init.lua"

-- Simple test framework
local function assertEquals(expected, actual, message)
  if expected ~= actual then
    error(message or ("Expected " .. tostring(expected) .. " but got " .. tostring(actual)))
  end
end

local function assertIsTable(value, message)
  if type(value) ~= "table" then
    error(message or ("Expected a table but got " .. type(value)))
  end
end

print("\nTest group: nvim-markdown-preview")

-- Load the module
package.loaded["nvim-markdown-preview"] = nil
local markdown_preview = require("nvim-markdown-preview")

-- Tests
print(" - Running test: loads with correct defaults")
do
  -- Run the setup function with default settings
  markdown_preview.setup()
  
  -- Check default settings
  assertEquals(8890, markdown_preview.config.port)
  assertEquals(true, markdown_preview.config.open_browser)
  assertEquals(true, markdown_preview.config.auto_refresh)
  assertEquals(300, markdown_preview.config.refresh_delay)
  print("   [PASS] loads with correct defaults")
end

print(" - Running test: allows custom configuration")
do
  -- Reset module
  package.loaded["nvim-markdown-preview"] = nil
  markdown_preview = require("nvim-markdown-preview")
  
  -- Run setup with custom settings
  markdown_preview.setup({
    port = 9999,
    open_browser = false,
    refresh_delay = 500
  })
  
  -- Check if custom settings were applied
  assertEquals(9999, markdown_preview.config.port)
  assertEquals(false, markdown_preview.config.open_browser)
  assertEquals(500, markdown_preview.config.refresh_delay)
  assertEquals(true, markdown_preview.config.auto_refresh) -- unchanged default
  print("   [PASS] allows custom configuration")
end

print(" - Running test: can get markdown content from buffer")
do
  -- Reset module
  package.loaded["nvim-markdown-preview"] = nil
  markdown_preview = require("nvim-markdown-preview")
  
  local content = markdown_preview.get_buffer_content()
  assertEquals("# Test Markdown\n\nThis is a test.", content)
  print("   [PASS] can get markdown content from buffer")
end

print(" - Running test: can start and stop preview")
do
  -- Reset module
  package.loaded["nvim-markdown-preview"] = nil
  markdown_preview = require("nvim-markdown-preview")
  markdown_preview.setup()
  
  -- Start preview
  markdown_preview.start_preview()
  assertEquals(true, markdown_preview.is_preview_active())
  
  -- Stop preview
  markdown_preview.stop_preview()
  assertEquals(false, markdown_preview.is_preview_active())
  print("   [PASS] can start and stop preview")
end

print(" - Running test: won't start preview for non-markdown files")
do
  -- Reset module
  package.loaded["nvim-markdown-preview"] = nil
  markdown_preview = require("nvim-markdown-preview")
  
  -- Change filetype to non-markdown
  vim.bo[1].filetype = "lua"
  
  markdown_preview.setup()
  markdown_preview.start_preview()
  
  assertEquals(false, markdown_preview.is_preview_active())
  print("   [PASS] won't start preview for non-markdown files")
  
  -- Reset filetype for next test
  vim.bo[1].filetype = "markdown"
end

print(" - Running test: can toggle preview state")
do
  -- Reset module
  package.loaded["nvim-markdown-preview"] = nil
  markdown_preview = require("nvim-markdown-preview")
  markdown_preview.setup()
  
  -- Initially off
  assertEquals(false, markdown_preview.is_preview_active())
  
  -- Toggle on
  markdown_preview.toggle_preview()
  assertEquals(true, markdown_preview.is_preview_active())
  
  -- Toggle off
  markdown_preview.toggle_preview()
  assertEquals(false, markdown_preview.is_preview_active())
  print("   [PASS] can toggle preview state")
end

-- Restore io.open
io.open = old_io_open

print("\nAll tests passed!")