-- Plugin: LiveMD.nvim
-- Server management module

local config = require('livemd.config')
local utils = require('livemd.utils')

local M = {}

-- State variables
local server_job_id = nil
local preview_file = nil
local preview_url = nil

-- Convert markdown to HTML
local function markdown_to_html(markdown)
  local html_template = [[
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LiveMD Preview</title>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/highlight.js@11.7.0/lib/highlight.min.js"></script>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/highlight.js@11.7.0/styles/github.min.css">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
    }
    pre {
      background-color: #f6f8fa;
      border-radius: 3px;
      padding: 16px;
      overflow: auto;
    }
    code {
      font-family: SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace;
      font-size: 85%;
    }
    img {
      max-width: 100%;
    }
    blockquote {
      padding: 0 1em;
      color: #6a737d;
      border-left: 0.25em solid #dfe2e5;
      margin: 0;
    }
    table {
      border-spacing: 0;
      border-collapse: collapse;
      margin-bottom: 16px;
    }
    table th, table td {
      padding: 6px 13px;
      border: 1px solid #dfe2e5;
    }
    table tr {
      background-color: #fff;
      border-top: 1px solid #c6cbd1;
    }
    table tr:nth-child(2n) {
      background-color: #f6f8fa;
    }
    .refresh-info {
      position: fixed;
      bottom: 10px;
      right: 10px;
      background: rgba(0,0,0,0.7);
      color: white;
      padding: 5px 10px;
      border-radius: 5px;
      font-size: 12px;
      z-index: 1000;
    }
  </style>
</head>
<body>
  <div id="content"></div>
  <div class="refresh-info">
    Auto-refreshing | Last update: <span id="last-update"></span>
  </div>

  <script>
    // Configure marked with highlight.js
    marked.setOptions({
      highlight: function(code, lang) {
        const language = hljs.getLanguage(lang) ? lang : 'plaintext';
        return hljs.highlight(code, { language }).value;
      },
      langPrefix: 'hljs language-'
    });

    // Initial markdown render
    let lastModified = Date.now();
    document.getElementById('last-update').textContent = new Date().toLocaleTimeString();
    document.getElementById('content').innerHTML = marked.parse(decodeURIComponent(`MARKDOWN_CONTENT`));
    
    // Function to check for updates
    function checkForUpdates() {
      fetch(window.location.pathname + '?t=' + new Date().getTime(), {
        method: 'HEAD'
      })
      .then(response => {
        const fileModified = new Date(response.headers.get('last-modified')).getTime();
        if (fileModified > lastModified) {
          console.log('File updated, refreshing content');
          lastModified = fileModified;
          location.reload();
        }
      })
      .catch(err => console.error('Error checking for updates:', err));
    }

    // Check for updates every second
    setInterval(checkForUpdates, 1000);
  </script>
</body>
</html>
  ]]
  
  -- Properly encode the markdown content for JS
  local encoded_content = markdown:gsub('\\', '\\\\'):gsub('`', '\\`'):gsub('\n', '\\n')
  local html = html_template:gsub('MARKDOWN_CONTENT', encoded_content)
  
  return html
end

-- Start HTTP server using built-in Neovim job functions
function M.start_server()
  if server_job_id then
    vim.notify("LiveMD server is already running", vim.log.levels.INFO)
    return true
  end
  
  -- Create temporary file for preview
  preview_file = vim.fn.tempname() .. '.html'
  
  -- Get content and create HTML
  local content = utils.get_buffer_content()
  local html = markdown_to_html(content)
  
  -- Write HTML to file
  local file = io.open(preview_file, "w")
  if not file then
    vim.notify("Failed to create preview file: " .. preview_file, vim.log.levels.ERROR)
    return false
  end
  
  file:write(html)
  file:close()
  
  vim.notify("Created preview file: " .. preview_file, vim.log.levels.INFO)
  
  -- Start HTTP server using Neovim job API for better control
  local port = config.options.port
  local preview_dir = vim.fn.fnamemodify(preview_file, ":h")
  
  local cmd
  local args = {}
  
  if vim.fn.executable('python3') == 1 then
    cmd = 'python3'
  else
    cmd = 'python'
  end
  
  -- Using built-in Python HTTP server
  args = {'-m', 'http.server', tostring(port), '--bind', '127.0.0.1', '--directory', preview_dir}
  
  vim.notify("Starting server with command: " .. cmd .. " " .. table.concat(args, " "), vim.log.levels.INFO)
  
  -- Use Neovim's built-in job API
  -- Use unpack or table.unpack depending on Lua version
  local unpack_fn = table.unpack or unpack
  server_job_id = vim.fn.jobstart({cmd, unpack_fn(args)}, {
    on_exit = function(job_id, exit_code, event_type)
      vim.notify("HTTP server exited with code: " .. exit_code, vim.log.levels.INFO)
      server_job_id = nil
    end,
    on_stderr = function(job_id, data, event_type)
      if data and #data > 0 and data[1] ~= "" then
        -- Python's SimpleHTTPServer logs access to stderr
        -- Only show real errors, not normal HTTP access logs
        -- Check if it's a normal HTTP access log with status codes we want to ignore
        local is_http_access_log = data[1]:match('127%.0%.0%.1%s%-%s%-%s%[.*%]%s"[A-Z]+ .*HTTP/1%.1"%s%d+ %-')
        
        -- Common success/redirect status codes we want to ignore: 200, 204, 301, 302, 304, 307
        local is_success_or_redirect = data[1]:match('HTTP/1%.1"%s+[23]0[01247]%s+')
        
        -- Notify only if this isn't a regular access log or it contains an error status
        if not is_http_access_log or not is_success_or_redirect then
          vim.notify("HTTP server error: " .. vim.inspect(data), vim.log.levels.WARN)
        end
      end
    end,
    on_stdout = function(job_id, data, event_type)
      if data and #data > 0 and data[1] ~= "" then
        -- Python's HTTP server doesn't normally log to stdout,
        -- so any stdout is probably important and should be shown
        -- But still check for HTTP access logs just in case
        local is_http_access_log = data[1]:match('127%.0%.0%.1%s%-%s%-%s%[.*%]%s"[A-Z]+ .*HTTP/1%.1"%s%d+ %-')
        local is_success_or_redirect = data[1]:match('HTTP/1%.1"%s+[23]0[01247]%s+')
        
        if not is_http_access_log or not is_success_or_redirect then
          vim.notify("HTTP server output: " .. vim.inspect(data), vim.log.levels.INFO)
        end
      end
    end,
    detach = true  -- Allow server to keep running if Neovim exits
  })
  
  if not server_job_id or server_job_id <= 0 then
    vim.notify("Failed to start HTTP server", vim.log.levels.ERROR)
    return false
  end
  
  -- Set URL for the preview
  preview_url = string.format("http://localhost:%d/%s", port, vim.fn.fnamemodify(preview_file, ":t"))
  
  vim.notify("LiveMD preview available at: " .. preview_url, vim.log.levels.INFO)
  
  return true
end

-- Update the preview content
function M.update_preview()
  if not server_job_id or not preview_file then 
    return 
  end
  
  -- Check if the buffer still exists
  if not utils.is_buffer_valid() then
    vim.notify("Preview buffer no longer exists", vim.log.levels.WARN)
    M.stop_server()
    return
  end
  
  -- Get the current buffer content
  local content = utils.get_buffer_content()
  local html = markdown_to_html(content)
  
  -- Write to file
  local file = io.open(preview_file, "w")
  if file then
    file:write(html)
    file:close()
    vim.notify("Preview updated", vim.log.levels.INFO)
  else
    vim.notify("Failed to update preview file", vim.log.levels.ERROR)
  end
end

-- Open the browser with the preview URL
function M.open_browser()
  if not preview_url then
    vim.notify("No preview URL available", vim.log.levels.ERROR)
    return
  end
  
  local cmd
  
  if config.options.browser_command then
    cmd = config.options.browser_command .. " " .. preview_url
  else
    -- Auto-detect platform and browser
    if vim.fn.has("mac") == 1 then
      cmd = "open " .. preview_url
    elseif vim.fn.has("unix") == 1 then
      cmd = "xdg-open " .. preview_url
    elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
      cmd = "start " .. preview_url
    else
      vim.notify("Unsupported platform. Please open " .. preview_url .. " manually.", vim.log.levels.WARN)
      return
    end
  end
  
  vim.fn.jobstart(cmd, {detach = true})
  vim.notify("LiveMD preview opened in browser", vim.log.levels.INFO)
end

-- Stop the preview server
function M.stop_server()
  if server_job_id then
    -- Try to stop server gracefully
    vim.fn.jobstop(server_job_id)
    
    -- Delete preview file
    if preview_file and vim.fn.filereadable(preview_file) == 1 then
      vim.fn.delete(preview_file)
    end
    
    -- Reset all state variables
    server_job_id = nil
    preview_url = nil
    preview_file = nil
    
    vim.notify("LiveMD preview stopped", vim.log.levels.INFO)
  end
end

-- Check if server is running
function M.is_server_running()
  return server_job_id ~= nil
end

-- Get the current preview URL
function M.get_preview_url()
  return preview_url
end

return M