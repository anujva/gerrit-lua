local api = require('gerrit.api')
local config = require('gerrit.config')
local utils = require('gerrit.utils')

local M = {}

-- State for diff viewing
local diff_state = {
  current_change = nil,
  current_revision = nil,
  current_file = nil,
  file_list = {},
  file_index = 1,
}

-- Show diff for a specific file
function M.show_file_diff(change_id, revision_id, file_path)
  diff_state.current_change = change_id
  diff_state.current_revision = revision_id
  diff_state.current_file = file_path
  
  
  utils.show_progress("Loading diff for " .. utils.get_filename(file_path))
  
  api.get_file_diff(change_id, revision_id, file_path, function(diff, error)
    if error then
      utils.show_error("Failed to load diff: " .. error)
      return
    end
    
    if not diff then
      utils.show_error("Diff data is nil")
      return
    end
    
    M.display_diff(file_path, diff)
  end)
end

-- Display diff content in a buffer
function M.display_diff(file_path, diff)
  local lines = {}
  local highlights = {}
  
  -- Header information
  table.insert(lines, "Diff: " .. file_path)
  table.insert(lines, string.rep("=", math.min(80, #file_path + 6)))
  table.insert(lines, "")
  
  if diff.meta_a and diff.meta_b then
    table.insert(lines, "--- " .. (diff.meta_a.name or file_path))
    table.insert(lines, "+++ " .. (diff.meta_b.name or file_path))
    table.insert(lines, "")
  end
  
  -- Process diff content
  if diff.content then
    for _, content_block in ipairs(diff.content) do
      if content_block.ab then
        -- Context lines (unchanged)
        for _, line in ipairs(content_block.ab) do
          table.insert(lines, " " .. line)
        end
      elseif content_block.a or content_block.b then
        -- Changed lines
        if content_block.a then
          for _, line in ipairs(content_block.a) do
            local line_num = #lines + 1
            table.insert(lines, "-" .. line)
            table.insert(highlights, {
              line = line_num,
              hl_group = "DiffDelete"
            })
          end
        end
        if content_block.b then
          for _, line in ipairs(content_block.b) do
            local line_num = #lines + 1
            table.insert(lines, "+" .. line)
            table.insert(highlights, {
              line = line_num,
              hl_group = "DiffAdd"
            })
          end
        end
      end
      
      -- Add hunk header if available
      if content_block.ab and #lines > 6 then -- Don't add header for first block
        table.insert(lines, "")
      end
    end
  else
    table.insert(lines, "No diff content available")
  end
  
  -- Add navigation help
  table.insert(lines, "")
  table.insert(lines, "Navigation: ]f/[f (next/prev file), ]h/[h (next/prev hunk), gc (add comment)")
  
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
    buf, win = utils.create_split("horizontal")
  end
  
  -- Set buffer content
  utils.set_buffer_content(buf, lines)
  utils.setup_temp_buffer(buf, "gerrit-diff")
  
  -- Apply highlights
  local ns = vim.api.nvim_create_namespace("gerrit_diff_highlights")
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ns, hl.hl_group, hl.line - 1, 0, -1)
  end
  
  -- Enable diff mode for better visualization
  vim.api.nvim_win_set_option(win, 'diff', false) -- Don't use vim's diff mode
  vim.api.nvim_buf_set_option(buf, 'syntax', 'diff')
  
  -- Set buffer name for identification
  vim.api.nvim_buf_set_name(buf, "gerrit://diff/" .. diff_state.current_change .. "/" .. file_path)
  
  -- Register buffer
  local gerrit = require('gerrit')
  gerrit.register_buffer(buf)
  
  utils.clear_echo()
end

-- Navigate to next file in change
function M.next_file()
  if not diff_state.current_change then
    utils.show_error("No active change")
    return
  end
  
  -- Get file list from current change
  local gerrit = require('gerrit')
  local state = gerrit.get_state()
  
  if not state.current_change or not state.current_change.revisions then
    utils.show_error("No file list available")
    return
  end
  
  local revision = state.current_change.revisions[state.current_change.current_revision]
  if not revision or not revision.files then
    utils.show_error("No files in current revision")
    return
  end
  
  -- Build file list
  local files = {}
  for file_path, _ in pairs(revision.files) do
    if file_path ~= "/COMMIT_MSG" then
      table.insert(files, file_path)
    end
  end
  table.sort(files)
  
  if #files == 0 then
    utils.show_error("No files to navigate")
    return
  end
  
  -- Find current file index
  local current_index = 1
  for i, file_path in ipairs(files) do
    if file_path == diff_state.current_file then
      current_index = i
      break
    end
  end
  
  -- Move to next file
  local next_index = current_index + 1
  if next_index > #files then
    next_index = 1 -- Wrap to beginning
  end
  
  M.show_file_diff(diff_state.current_change, diff_state.current_revision, files[next_index])
end

-- Navigate to previous file in change
function M.prev_file()
  if not diff_state.current_change then
    utils.show_error("No active change")
    return
  end
  
  -- Get file list from current change
  local gerrit = require('gerrit')
  local state = gerrit.get_state()
  
  if not state.current_change or not state.current_change.revisions then
    utils.show_error("No file list available")
    return
  end
  
  local revision = state.current_change.revisions[state.current_change.current_revision]
  if not revision or not revision.files then
    utils.show_error("No files in current revision")
    return
  end
  
  -- Build file list
  local files = {}
  for file_path, _ in pairs(revision.files) do
    if file_path ~= "/COMMIT_MSG" then
      table.insert(files, file_path)
    end
  end
  table.sort(files)
  
  if #files == 0 then
    utils.show_error("No files to navigate")
    return
  end
  
  -- Find current file index
  local current_index = 1
  for i, file_path in ipairs(files) do
    if file_path == diff_state.current_file then
      current_index = i
      break
    end
  end
  
  -- Move to previous file
  local prev_index = current_index - 1
  if prev_index < 1 then
    prev_index = #files -- Wrap to end
  end
  
  M.show_file_diff(diff_state.current_change, diff_state.current_revision, files[prev_index])
end

-- Show unified diff for entire change
function M.show_change_diff(change_id, revision_id)
  if not change_id then
    utils.show_error("No change ID provided")
    return
  end
  
  revision_id = revision_id or "current"
  
  utils.show_progress("Loading change diff")
  
  -- Get change details first to get file list
  api.get_change_detail(change_id, function(change, error)
    if error then
      utils.show_error("Failed to load change: " .. error)
      return
    end
    
    local revision = change.revisions[change.current_revision]
    if not revision or not revision.files then
      utils.show_error("No files in revision")
      return
    end
    
    -- Collect all files for diff
    local files = {}
    for file_path, _ in pairs(revision.files) do
      if file_path ~= "/COMMIT_MSG" then
        table.insert(files, file_path)
      end
    end
    table.sort(files)
    
    if #files == 0 then
      utils.show_error("No files to show diff for")
      return
    end
    
    -- Load diff for first file (we'll show file navigation)
    diff_state.file_list = files
    diff_state.file_index = 1
    M.show_file_diff(change_id, revision_id, files[1])
  end)
end

-- Get current diff state (for debugging)
function M.get_state()
  return diff_state
end

return M