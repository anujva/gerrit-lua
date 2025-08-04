local M = {}

-- Format timestamp for display
function M.format_timestamp(timestamp)
  if not timestamp then
    return "Unknown"
  end
  
  -- Gerrit timestamps are in "2023-12-01 10:30:45.000000000" format
  local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
  local year, month, day, hour, min, sec = timestamp:match(pattern)
  
  if not year then
    return timestamp -- Return as-is if parsing fails
  end
  
  return string.format("%s-%s-%s %s:%s:%s", year, month, day, hour, min, sec)
end

-- Truncate text to specified length with ellipsis
function M.truncate(text, max_length)
  if not text then
    return ""
  end
  
  if #text <= max_length then
    return text
  end
  
  return text:sub(1, max_length - 3) .. "..."
end

-- Get file extension from path
function M.get_file_extension(file_path)
  if not file_path then
    return ""
  end
  
  local extension = file_path:match("%.([^%.]+)$")
  return extension or ""
end

-- Get filename from path
function M.get_filename(file_path)
  if not file_path then
    return ""
  end
  
  local filename = file_path:match("([^/]+)$")
  return filename or file_path
end

-- Create a centered floating window
function M.create_centered_float(width, height, title)
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  
  -- Calculate position for centering
  local win_width = math.floor(screen_width * width)
  local win_height = math.floor(screen_height * height)
  local row = math.floor((screen_height - win_height) / 2)
  local col = math.floor((screen_width - win_width) / 2)
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Window options
  local opts = {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = title or "Gerrit",
    title_pos = 'center',
  }
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, true, opts)
  
  return buf, win
end

-- Create a split window (vertical or horizontal)
function M.create_split(direction, size)
  direction = direction or "vertical"
  
  if direction == "vertical" then
    if size then
      vim.cmd("vertical " .. size .. "split")
    else
      vim.cmd("vsplit")
    end
  else
    if size then
      vim.cmd(size .. "split")
    else
      vim.cmd("split")
    end
  end
  
  return vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
end

-- Set buffer content safely
function M.set_buffer_content(buf, lines)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  
  local ok, err = pcall(function()
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'readonly', true)
  end)
  
  if not ok then
    vim.notify("gerrit.nvim: Failed to set buffer content: " .. tostring(err), vim.log.levels.WARN)
    return false
  end
  
  return true
end

-- Set buffer as temporary and scratch
function M.setup_temp_buffer(buf, filetype)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  
  if filetype then
    vim.api.nvim_buf_set_option(buf, 'filetype', filetype)
  end
end

-- Show error message
function M.show_error(message)
  vim.api.nvim_err_writeln("gerrit.nvim: " .. message)
end

-- Show info message
function M.show_info(message)
  vim.api.nvim_echo({{ "gerrit.nvim: " .. message, "Normal" }}, false, {})
end

-- Show success message
function M.show_success(message)
  vim.api.nvim_echo({{ "gerrit.nvim: " .. message, "DiagnosticOk" }}, false, {})
end

-- Escape special characters for display
function M.escape_display(text)
  if not text then
    return ""
  end
  
  return text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end

-- Parse change status and return appropriate highlight group
function M.get_status_highlight(status)
  local highlights = {
    NEW = "DiagnosticInfo",
    MERGED = "DiagnosticOk",
    ABANDONED = "DiagnosticWarn",
    DRAFT = "Comment",
  }
  
  return highlights[status] or "Normal"
end

-- Create a simple progress indicator
function M.show_progress(message)
  vim.api.nvim_echo({{ "gerrit.nvim: " .. message .. "...", "DiagnosticInfo" }}, false, {})
end

-- Clear echo area
function M.clear_echo()
  vim.api.nvim_echo({{"", "Normal"}}, false, {})
end

-- Check if string is empty or nil
function M.is_empty(str)
  return not str or str == ""
end

-- Safe table access
function M.safe_get(table, ...)
  local current = table
  for _, key in ipairs({...}) do
    if type(current) ~= "table" or current[key] == nil then
      return nil
    end
    current = current[key]
  end
  return current
end

return M