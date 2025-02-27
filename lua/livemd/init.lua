-- Plugin: LiveMD.nvim
-- A lightweight markdown preview plugin for NeoVim

local M = {}

-- Configuration with defaults
M.config = {
  port = 8890,
  open_browser = true,
  auto_refresh = true,
  refresh_delay = 300, -- ms
  css_path = nil, -- use default styling
  browser_command = nil, -- auto-detect the default browser
  inactivity_timeout = 5 * 60, -- 5 minutes in seconds
}

-- State variables
local server_job_id = nil
local current_buffer = nil
local last_update_time = 0
local preview_url = nil
local preview_file = nil
local inactivity_timer_id = nil

-- Initialize the plugin
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  
  -- Create autocommands for markdown files
  vim.api.nvim_create_augroup("LiveMD", { clear = true })
  
  -- Auto-update preview when text changes
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "BufWritePost"}, {
    group = "LiveMD",
    pattern = {"*.md", "*.markdown"},
    callback = function()
      local current_buf = vim.api.nvim_get_current_buf()
      
      -- Only update if this buffer is the current preview target
      if current_buf == current_buffer and M.config.auto_refresh then
        local current_time = vim.loop.now()
        if current_time - last_update_time > M.config.refresh_delay then
          last_update_time = current_time
          M.update_preview()
          M.reset_inactivity_timer()
        end
      end
    end
  })
  
  -- Reset inactivity timer on cursor movements in the preview buffer
  vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
    group = "LiveMD",
    callback = function()
      local current_buf = vim.api.nvim_get_current_buf()
      if current_buf == current_buffer and server_job_id then
        M.reset_inactivity_timer()
      end
    end
  })
  
  -- Remove the BufEnter autocmd that was automatically showing the prompt
  -- We'll only show the prompt when the user explicitly tries to preview a new markdown
  
  -- Clean up when leaving Neovim
  vim.api.nvim_create_autocmd("VimLeave", {
    group = "LiveMD",
    callback = function()
      M.stop_preview()
    end
  })
  
  -- Register commands
  vim.api.nvim_create_user_command(
    'LiveMDStart',
    function()
      M.start_preview()
    end,
    {
      desc = 'Start LiveMD preview',
      nargs = 0,
    }
  )

  vim.api.nvim_create_user_command(
    'LiveMDStop',
    function()
      M.stop_preview()
    end,
    {
      desc = 'Stop LiveMD preview',
      nargs = 0,
    }
  )
  
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

-- Reset the inactivity timer
function M.reset_inactivity_timer()
  -- Clear existing timer
  if inactivity_timer_id then
    vim.fn.timer_stop(inactivity_timer_id)
    inactivity_timer_id = nil
  end
  
  -- Set new timer (convert seconds to milliseconds)
  inactivity_timer_id = vim.fn.timer_start(M.config.inactivity_timeout * 1000, function()
    vim.schedule(function()
      if server_job_id then
        vim.notify("Markdown preview closed due to inactivity (" .. M.config.inactivity_timeout .. " seconds)", vim.log.levels.INFO)
        M.stop_preview()
      end
    end)
  end)
end

-- Get current buffer content
function M.get_buffer_content()
  -- Get content from the buffer being previewed, not necessarily the current buffer
  if not current_buffer then
    return ""
  end
  
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(current_buffer) then
    vim.notify("Preview buffer no longer exists", vim.log.levels.WARN)
    M.stop_preview()
    return ""
  end
  
  local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, -1, false)
  return table.concat(lines, "\n")
end

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
local function start_server()
  if server_job_id then
    vim.notify("LiveMD server is already running", vim.log.levels.INFO)
    return true
  end
  
  -- Create temporary file for preview
  preview_file = vim.fn.tempname() .. '.html'
  
  -- Get content and create HTML
  local content = M.get_buffer_content()
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
  local port = M.config.port
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
  if server_job_id then
    -- If different buffer, prompt to switch
    if buf ~= current_buffer then
      local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
      
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
        "Current preview: " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(current_buffer), ":t")
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
        current_buffer = buf
        M.update_preview()
        M.reset_inactivity_timer()
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
      
      return
    else
      -- Already previewing this buffer
      vim.notify("Already previewing current buffer", vim.log.levels.INFO)
      return
    end
  end
  
  -- Set current buffer
  current_buffer = buf
  
  -- Start the server
  if not start_server() then
    return
  end
  
  -- Update the preview content
  M.update_preview()
  
  -- Open browser if configured
  if M.config.open_browser then
    M.open_browser()
  end
  
  -- Start inactivity timer
  M.reset_inactivity_timer()
end

-- Open the browser with the preview URL
function M.open_browser()
  if not preview_url then
    vim.notify("No preview URL available", vim.log.levels.ERROR)
    return
  end
  
  local cmd
  
  if M.config.browser_command then
    cmd = M.config.browser_command .. " " .. preview_url
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

-- Update the preview content
function M.update_preview()
  if not server_job_id or not preview_file then 
    return 
  end
  
  -- Check if the buffer still exists
  if not vim.api.nvim_buf_is_valid(current_buffer) then
    vim.notify("Preview buffer no longer exists", vim.log.levels.WARN)
    M.stop_preview()
    return
  end
  
  -- Get the current buffer content
  local content = M.get_buffer_content()
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

-- Stop the preview server
function M.stop_preview()
  if server_job_id then
    -- Try to stop server gracefully
    vim.fn.jobstop(server_job_id)
    
    -- Delete preview file
    if preview_file and vim.fn.filereadable(preview_file) == 1 then
      vim.fn.delete(preview_file)
    end
    
    -- Stop inactivity timer if running
    if inactivity_timer_id then
      vim.fn.timer_stop(inactivity_timer_id)
      inactivity_timer_id = nil
    end
    
    -- Reset all state variables
    server_job_id = nil
    current_buffer = nil
    preview_url = nil
    preview_file = nil
    
    vim.notify("LiveMD preview stopped", vim.log.levels.INFO)
  end
end

-- Check if preview is active
function M.is_preview_active()
  return server_job_id ~= nil and current_buffer == vim.api.nvim_get_current_buf()
end

return M