local config = require('gerrit.config')
local utils = require('gerrit.utils')

local M = {}

-- State for current UI views
local ui_state = {
  change_list = {
    changes = {},
    selected_index = 1,
  },
  change_detail = {
    change = nil,
  },
}

-- Show list of changes in a floating window
function M.show_change_list(changes)
  ui_state.change_list.changes = changes
  ui_state.change_list.selected_index = 1
  
  -- Format changes for display
  local lines = {}
  local highlights = {}
  
  -- Header
  table.insert(lines, "Gerrit Changes")
  table.insert(lines, string.rep("=", 80))
  table.insert(lines, "")
  
  for i, change in ipairs(changes) do
    local status_hl = utils.get_status_highlight(change.status)
    local line_num = #lines + 1
    
    -- Format change line
    local line = string.format("%s %s %s | %s | %s",
      change.status,
      change._number or change.id,
      utils.truncate(change.subject, 40),
      change.owner and (change.owner.name or change.owner.username) or "Unknown",
      utils.format_timestamp(change.updated)
    )
    
    table.insert(lines, line)
    
    -- Store highlight information
    table.insert(highlights, {
      line = line_num,
      col_start = 0,
      col_end = #change.status,
      hl_group = status_hl
    })
  end
  
  if #changes == 0 then
    table.insert(lines, "No changes found")
  end
  
  -- Add help text
  table.insert(lines, "")
  table.insert(lines, "Press <CR> to open, 'r' to refresh, 'q' to quit")
  
  -- Create split window
  local buf, win = utils.create_split("vertical", 60)
  
  -- Set buffer content
  utils.set_buffer_content(buf, lines)
  utils.setup_temp_buffer(buf, "gerrit-changes")
  
  -- Apply highlights
  local ns = vim.api.nvim_create_namespace("gerrit_highlights")
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ns, hl.hl_group, hl.line - 1, hl.col_start, hl.col_end)
  end
  
  -- Set cursor to first change
  if #changes > 0 then
    vim.api.nvim_win_set_cursor(win, {4, 0}) -- Skip header lines
  end
  
  -- Register buffer
  local gerrit = require('gerrit')
  gerrit.register_buffer(buf)
  
  -- Set buffer name for identification
  vim.api.nvim_buf_set_name(buf, "gerrit://changes")
end

-- Open selected change from change list
function M.open_selected_change()
  local line_num = vim.api.nvim_win_get_cursor(0)[1]
  local changes = ui_state.change_list.changes
  
  if not changes or #changes == 0 then
    utils.show_error("No changes available")
    return
  end
  
  -- Calculate change index (skip header lines: "Gerrit Changes", "===...", "")
  local change_index = line_num - 3
  
  
  if change_index < 1 or change_index > #changes then
    utils.show_error("No change selected (line " .. line_num .. ", calculated index " .. change_index .. ", " .. #changes .. " changes available)")
    return
  end
  
  local change = changes[change_index]
  if not change or not change.id then
    utils.show_error("Invalid change data")
    return
  end
  
  -- Get current buffer and window to reuse them
  local current_buf = vim.api.nvim_get_current_buf()
  local current_win = vim.api.nvim_get_current_win()
  
  -- Clear the change list state
  ui_state.change_list.changes = {}
  
  -- Show loading message
  utils.show_progress("Loading change details")
  
  -- Get change details and update current buffer instead of creating new window
  local api = require('gerrit.api')
  api.get_change_detail(change.id, function(detailed_change, error)
    if error then
      utils.show_error("Failed to load change: " .. error)
      return
    end
    
    -- Update current buffer with change details
    M.update_buffer_with_change_detail(current_buf, detailed_change)
    
    -- Update plugin state
    local gerrit = require('gerrit')
    local state = gerrit.get_state()
    state.current_change = detailed_change
    state.current_revision = detailed_change.current_revision
  end)
end

-- Update existing buffer with change details (for reusing windows)
function M.update_buffer_with_change_detail(buf, change)
  ui_state.change_detail.change = change
  
  local lines = {}
  
  -- Header
  table.insert(lines, "Change Details")
  table.insert(lines, string.rep("=", 80))
  table.insert(lines, "")
  
  -- Basic information
  table.insert(lines, "Change-Id: " .. (change.change_id or "N/A"))
  table.insert(lines, "Number: " .. (change._number or "N/A"))
  table.insert(lines, "Subject: " .. (change.subject or "N/A"))
  table.insert(lines, "Status: " .. (change.status or "N/A"))
  table.insert(lines, "Project: " .. (change.project or "N/A"))
  table.insert(lines, "Branch: " .. (change.branch or "N/A"))
  table.insert(lines, "Owner: " .. (utils.safe_get(change, "owner", "name") or utils.safe_get(change, "owner", "username") or "N/A"))
  table.insert(lines, "Created: " .. utils.format_timestamp(change.created))
  table.insert(lines, "Updated: " .. utils.format_timestamp(change.updated))
  table.insert(lines, "")
  
  -- Description
  if change.revisions and change.current_revision then
    local current_rev = change.revisions[change.current_revision]
    if current_rev and current_rev.commit and current_rev.commit.message then
      table.insert(lines, "Description:")
      table.insert(lines, string.rep("-", 40))
      
      local description_lines = vim.split(current_rev.commit.message, "\n")
      for _, desc_line in ipairs(description_lines) do
        table.insert(lines, desc_line)
      end
      table.insert(lines, "")
    end
  end
  
  -- Files changed  
  local file_list = {}
  local files_start_line = nil
  if change.revisions and change.current_revision then
    local current_rev = change.revisions[change.current_revision]
    if current_rev and current_rev.files then
      table.insert(lines, "Files Changed:")
      table.insert(lines, string.rep("-", 40))
      files_start_line = #lines + 1 -- Track where files start
      
      -- Sort files for consistent ordering
      local sorted_files = {}
      for file_path, _ in pairs(current_rev.files) do
        if file_path ~= "/COMMIT_MSG" then
          table.insert(sorted_files, file_path)
        end
      end
      table.sort(sorted_files)
      
      for _, file_path in ipairs(sorted_files) do
        local file_info = current_rev.files[file_path]
        local status = file_info.status or "M"
        table.insert(lines, string.format("[%s] %s", status, file_path))
        table.insert(file_list, file_path) -- Keep track of files in order
      end
      table.insert(lines, "")
    end
  end
  
  -- Comments summary
  if change.total_comment_count and change.total_comment_count > 0 then
    table.insert(lines, "Comments: " .. change.total_comment_count)
    table.insert(lines, "")
  end
  
  -- Help
  table.insert(lines, "Commands:")
  table.insert(lines, "  :GerritDiff <file>  - Show diff for file")
  table.insert(lines, "  :GerritComment      - Add comment")
  table.insert(lines, "  :GerritApprove      - Approve change")
  table.insert(lines, "  :GerritReject       - Reject change")
  
  -- Add keybinding help text if we have files
  if file_list and #file_list > 0 and files_start_line then
    table.insert(lines, "")
    table.insert(lines, "Navigation:")
    table.insert(lines, "  'o' on a file line - Open diff for that file")
  end
  
  -- Update buffer content
  utils.set_buffer_content(buf, lines)
  utils.setup_temp_buffer(buf, "gerrit-change")
  
  -- Store file list and metadata for keybindings
  if file_list and #file_list > 0 and files_start_line then
    vim.b[buf].gerrit_change_id = change._number or change.id -- Use change number for API calls
    vim.b[buf].gerrit_revision_id = change.current_revision
    vim.b[buf].gerrit_file_list = file_list
    vim.b[buf].gerrit_files_start_line = files_start_line
    
    -- Add keybinding to open diff for selected file
    vim.api.nvim_buf_set_keymap(buf, 'n', 'o', 
      '<cmd>lua require("gerrit.ui").open_diff_for_selected_file()<CR>',
      { noremap = true, silent = true, desc = "Open diff for selected file" })
  end
  
  -- Register buffer
  local gerrit = require('gerrit')
  gerrit.register_buffer(buf)
  
  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, "gerrit://change/" .. change.id)
  
  utils.clear_echo()
end

-- Show detailed view of a change
function M.show_change_detail(change)
  ui_state.change_detail.change = change
  
  local lines = {}
  
  -- Header
  table.insert(lines, "Change Details")
  table.insert(lines, string.rep("=", 80))
  table.insert(lines, "")
  
  -- Basic information
  table.insert(lines, "Change-Id: " .. (change.change_id or "N/A"))
  table.insert(lines, "Number: " .. (change._number or "N/A"))
  table.insert(lines, "Subject: " .. (change.subject or "N/A"))
  table.insert(lines, "Status: " .. (change.status or "N/A"))
  table.insert(lines, "Project: " .. (change.project or "N/A"))
  table.insert(lines, "Branch: " .. (change.branch or "N/A"))
  table.insert(lines, "Owner: " .. (utils.safe_get(change, "owner", "name") or utils.safe_get(change, "owner", "username") or "N/A"))
  table.insert(lines, "Created: " .. utils.format_timestamp(change.created))
  table.insert(lines, "Updated: " .. utils.format_timestamp(change.updated))
  table.insert(lines, "")
  
  -- Description
  if change.revisions and change.current_revision then
    local current_rev = change.revisions[change.current_revision]
    if current_rev and current_rev.commit and current_rev.commit.message then
      table.insert(lines, "Description:")
      table.insert(lines, string.rep("-", 40))
      
      local description_lines = vim.split(current_rev.commit.message, "\n")
      for _, desc_line in ipairs(description_lines) do
        table.insert(lines, desc_line)
      end
      table.insert(lines, "")
    end
  end
  
  -- Files changed  
  local file_list = {}
  local files_start_line = nil
  if change.revisions and change.current_revision then
    local current_rev = change.revisions[change.current_revision]
    if current_rev and current_rev.files then
      table.insert(lines, "Files Changed:")
      table.insert(lines, string.rep("-", 40))
      files_start_line = #lines + 1 -- Track where files start
      
      -- Sort files for consistent ordering
      local sorted_files = {}
      for file_path, _ in pairs(current_rev.files) do
        if file_path ~= "/COMMIT_MSG" then
          table.insert(sorted_files, file_path)
        end
      end
      table.sort(sorted_files)
      
      for _, file_path in ipairs(sorted_files) do
        local file_info = current_rev.files[file_path]
        local status = file_info.status or "M"
        table.insert(lines, string.format("[%s] %s", status, file_path))
        table.insert(file_list, file_path) -- Keep track of files in order
      end
      table.insert(lines, "")
    end
  end
  
  -- Comments summary
  if change.total_comment_count and change.total_comment_count > 0 then
    table.insert(lines, "Comments: " .. change.total_comment_count)
    table.insert(lines, "")
  end
  
  -- Help
  table.insert(lines, "Commands:")
  table.insert(lines, "  :GerritDiff <file>  - Show diff for file")
  table.insert(lines, "  :GerritComment      - Add comment")
  table.insert(lines, "  :GerritApprove      - Approve change")
  table.insert(lines, "  :GerritReject       - Reject change")
  
  -- Use current buffer if it's a gerrit buffer, otherwise create split
  local current_buf = vim.api.nvim_get_current_buf()
  local current_name = vim.api.nvim_buf_get_name(current_buf)
  
  local buf, win
  if current_name:match("^gerrit://") then
    -- Reuse current gerrit buffer
    buf = current_buf
    win = vim.api.nvim_get_current_win()
  else
    -- Create new split for non-gerrit buffers
    buf, win = utils.create_split("vertical", 60)
  end
  
  utils.set_buffer_content(buf, lines)
  utils.setup_temp_buffer(buf, "gerrit-change")
  
  -- Store file list and metadata for keybindings
  if file_list and #file_list > 0 and files_start_line then
    vim.b[buf].gerrit_change_id = change._number or change.id -- Use change number for API calls
    vim.b[buf].gerrit_revision_id = change.current_revision
    vim.b[buf].gerrit_file_list = file_list
    vim.b[buf].gerrit_files_start_line = files_start_line
    
    -- Add keybinding to open diff for selected file
    vim.api.nvim_buf_set_keymap(buf, 'n', 'o', 
      '<cmd>lua require("gerrit.ui").open_diff_for_selected_file()<CR>',
      { noremap = true, silent = true, desc = "Open diff for selected file" })
    
    -- Update help text
    table.insert(lines, "")
    table.insert(lines, "Navigation:")
    table.insert(lines, "  'o' on a file line - Open diff for that file")
    utils.set_buffer_content(buf, lines)
  end
  
  -- Register buffer
  local gerrit = require('gerrit')
  gerrit.register_buffer(buf)
  
  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, "gerrit://change/" .. change.id)
end

-- Show file list for current change
function M.show_file_list(change)
  if not change.revisions or not change.current_revision then
    utils.show_error("No files found in change")
    return
  end
  
  local current_rev = change.revisions[change.current_revision]
  if not current_rev or not current_rev.files then
    utils.show_error("No files found in revision")
    return
  end
  
  local lines = {}
  local file_paths = {}
  
  -- Header
  table.insert(lines, "Files in Change " .. (change._number or change.id))
  table.insert(lines, string.rep("=", 60))
  table.insert(lines, "")
  
  -- List files
  for file_path, file_info in pairs(current_rev.files) do
    if file_path ~= "/COMMIT_MSG" then
      local status = file_info.status or "M"
      local line = string.format("[%s] %s", status, file_path)
      table.insert(lines, line)
      table.insert(file_paths, file_path)
    end
  end
  
  if #file_paths == 0 then
    table.insert(lines, "No files to show")
  else
    table.insert(lines, "")
    table.insert(lines, "Press <CR> to show diff, 'q' to quit")
  end
  
  -- Create floating window
  local buf, win = utils.create_centered_float(0.6, 0.8, "Files Changed")
  utils.set_buffer_content(buf, lines)
  utils.setup_temp_buffer(buf, "gerrit-files")
  
  -- Set up keymap to open file diff
  vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>',
    '<cmd>lua require("gerrit.ui").open_selected_file()<CR>',
    { noremap = true, silent = true })
  
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q',
    '<cmd>close<CR>',
    { noremap = true, silent = true })
  
  -- Store file paths for selection
  vim.b[buf].gerrit_file_paths = file_paths
  
  -- Position cursor on first file
  if #file_paths > 0 then
    vim.api.nvim_win_set_cursor(win, {4, 0})
  end
  
  -- Register buffer
  local gerrit = require('gerrit')
  gerrit.register_buffer(buf)
end

-- Open diff for selected file from file list
function M.open_selected_file()
  local buf = vim.api.nvim_get_current_buf()
  local file_paths = vim.b[buf].gerrit_file_paths
  
  if not file_paths then
    utils.show_error("No file paths available")
    return
  end
  
  local line_num = vim.api.nvim_win_get_cursor(0)[1]
  local file_index = line_num - 3 -- Skip header lines
  
  if file_index < 1 or file_index > #file_paths then
    utils.show_error("No file selected")
    return
  end
  
  local file_path = file_paths[file_index]
  local gerrit = require('gerrit')
  gerrit.show_diff(file_path)
  
  -- Close file list window
  vim.cmd('close')
end

-- Show loading indicator
function M.show_loading(message)
  local lines = {
    "",
    "  " .. (message or "Loading..."),
    "  Please wait...",
    "",
  }
  
  local buf, win = utils.create_centered_float(0.3, 0.2, "Gerrit")
  utils.set_buffer_content(buf, lines)
  utils.setup_temp_buffer(buf, "text")
  
  return buf, win
end

-- Close loading indicator
function M.close_loading(buf, win)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

-- Open diff for selected file from change details
function M.open_diff_for_selected_file()
  local buf = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  
  -- Get stored metadata
  local change_id = vim.b[buf].gerrit_change_id
  local revision_id = vim.b[buf].gerrit_revision_id
  local file_list = vim.b[buf].gerrit_file_list
  local files_start_line = vim.b[buf].gerrit_files_start_line
  
  if not change_id or not file_list or not files_start_line then
    utils.show_error("No file information available")
    return
  end
  
  -- Calculate which file is selected
  local file_index = cursor_line - files_start_line + 1
  
  
  if file_index < 1 or file_index > #file_list then
    utils.show_error("No file selected on this line")
    return
  end
  
  local selected_file = file_list[file_index]
  if not selected_file then
    utils.show_error("Invalid file selection")
    return
  end
  
  utils.show_info("Opening diff for: " .. selected_file)
  
  -- Open diff using the diff module
  local diff = require('gerrit.diff')
  diff.show_file_diff(change_id, revision_id, selected_file)
end

return M