local api = require('gerrit.api')
local config = require('gerrit.config')
local utils = require('gerrit.utils')

local M = {}

-- State for comment management
local comment_state = {
  comments_visible = true,
  namespace = nil,
  current_comments = {},
  draft_comments = {},
}

-- Initialize namespace for virtual text
local function ensure_namespace()
  if not comment_state.namespace then
    comment_state.namespace = vim.api.nvim_create_namespace("gerrit_comments")
  end
  return comment_state.namespace
end

-- Add comment at current cursor position
function M.add_comment_at_cursor(change_id, revision_id)
  if not change_id then
    utils.show_error("No active change")
    return
  end
  
  local buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(buf)
  
  -- Extract file path from buffer name
  local file_path = buf_name:match("gerrit://diff/[^/]+/(.+)$")
  if not file_path then
    utils.show_error("Not in a Gerrit diff buffer")
    return
  end
  
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  
  -- Prompt for comment text
  vim.ui.input({ prompt = "Comment: " }, function(comment_text)
    if not comment_text or comment_text:match("^%s*$") then
      utils.show_info("Comment cancelled")
      return
    end
    
    utils.show_progress("Adding comment")
    
    api.add_draft_comment(change_id, revision_id, file_path, line_num, comment_text, function(result, error)
      if error then
        utils.show_error("Failed to add comment: " .. error)
        return
      end
      
      utils.show_success("Comment added as draft")
      
      -- Refresh comments display
      M.load_comments(change_id)
    end)
  end)
end

-- Load comments for a change
function M.load_comments(change_id)
  if not change_id then
    return
  end
  
  -- Load both published and draft comments
  api.get_comments(change_id, function(comments, error)
    if error then
      utils.show_error("Failed to load comments: " .. error)
      return
    end
    
    comment_state.current_comments = comments or {}
    
    -- Load draft comments
    api.get_draft_comments(change_id, function(drafts, error)
      if error then
        utils.show_error("Failed to load draft comments: " .. error)
        return
      end
      
      comment_state.draft_comments = drafts or {}
      
      -- Display comments if enabled
      if comment_state.comments_visible then
        M.display_comments()
      end
    end)
  end)
end

-- Display comments using virtual text
function M.display_comments()
  local buf = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(buf)
  
  -- Extract file path from buffer name
  local file_path = buf_name:match("gerrit://diff/[^/]+/(.+)$")
  if not file_path then
    return
  end
  
  local ns = ensure_namespace()
  
  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  
  local conf = config.get()
  if not conf.ui.comments.virtual_text then
    return
  end
  
  -- Display published comments
  local file_comments = comment_state.current_comments[file_path]
  if file_comments then
    for _, comment in ipairs(file_comments) do
      if comment.line and comment.line > 0 then
        local line_idx = comment.line - 1
        local author = comment.author and (comment.author.name or comment.author.username) or "Unknown"
        local comment_text = utils.truncate(comment.message, 60)
        local virt_text = {{ "💬 " .. author .. ": " .. comment_text, "Comment" }}
        
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, line_idx, 0, {
          virt_text = virt_text,
          virt_text_pos = "eol",
        })
      end
    end
  end
  
  -- Display draft comments with different highlighting
  local draft_file_comments = comment_state.draft_comments[file_path]
  if draft_file_comments then
    for _, comment in ipairs(draft_file_comments) do
      if comment.line and comment.line > 0 then
        local line_idx = comment.line - 1
        local comment_text = utils.truncate(comment.message, 60)
        local virt_text = {{ "✏️ DRAFT: " .. comment_text, "DiagnosticWarn" }}
        
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, line_idx, 0, {
          virt_text = virt_text,
          virt_text_pos = "eol",
        })
      end
    end
  end
end

-- Toggle comments visibility
function M.toggle_comments()
  comment_state.comments_visible = not comment_state.comments_visible
  
  if comment_state.comments_visible then
    M.display_comments()
    utils.show_info("Comments shown")
  else
    local buf = vim.api.nvim_get_current_buf()
    local ns = ensure_namespace()
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    utils.show_info("Comments hidden")
  end
end

-- Show comments list in a floating window
function M.show_comments_list(change_id)
  if not change_id then
    utils.show_error("No change ID provided")
    return
  end
  
  utils.show_progress("Loading comments")
  
  api.get_comments(change_id, function(comments, error)
    if error then
      utils.show_error("Failed to load comments: " .. error)
      return
    end
    
    local lines = {}
    table.insert(lines, "Comments for Change")
    table.insert(lines, string.rep("=", 60))
    table.insert(lines, "")
    
    local has_comments = false
    
    -- Organize comments by file
    for file_path, file_comments in pairs(comments or {}) do
      if #file_comments > 0 then
        has_comments = true
        table.insert(lines, "File: " .. file_path)
        table.insert(lines, string.rep("-", 40))
        
        for _, comment in ipairs(file_comments) do
          local author = comment.author and (comment.author.name or comment.author.username) or "Unknown"
          local timestamp = utils.format_timestamp(comment.updated)
          
          table.insert(lines, string.format("Line %d | %s | %s", 
            comment.line or 0, author, timestamp))
          
          -- Split comment message into lines
          local comment_lines = vim.split(comment.message, "\n")
          for _, comment_line in ipairs(comment_lines) do
            table.insert(lines, "  " .. comment_line)
          end
          table.insert(lines, "")
        end
        table.insert(lines, "")
      end
    end
    
    if not has_comments then
      table.insert(lines, "No comments found")
    end
    
    table.insert(lines, "")
    table.insert(lines, "Press 'q' to close")
    
    -- Create floating window
    local buf, win = utils.create_centered_float(0.8, 0.8, "Comments")
    utils.set_buffer_content(buf, lines)
    utils.setup_temp_buffer(buf, "gerrit-comments")
    
    -- Close on 'q'
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<CR>', 
      { noremap = true, silent = true })
    
    -- Register buffer
    local gerrit = require('gerrit')
    gerrit.register_buffer(buf)
    
    utils.clear_echo()
  end)
end

-- Show draft comments for current user
function M.show_draft_comments(change_id)
  if not change_id then
    utils.show_error("No change ID provided")
    return
  end
  
  utils.show_progress("Loading draft comments")
  
  api.get_draft_comments(change_id, function(drafts, error)
    if error then
      utils.show_error("Failed to load draft comments: " .. error)
      return
    end
    
    local lines = {}
    table.insert(lines, "Draft Comments")
    table.insert(lines, string.rep("=", 60))
    table.insert(lines, "")
    
    local has_drafts = false
    
    -- Organize drafts by file
    for file_path, file_drafts in pairs(drafts or {}) do
      if #file_drafts > 0 then
        has_drafts = true
        table.insert(lines, "File: " .. file_path)
        table.insert(lines, string.rep("-", 40))
        
        for _, comment in ipairs(file_drafts) do
          table.insert(lines, string.format("Line %d:", comment.line or 0))
          
          -- Split comment message into lines
          local comment_lines = vim.split(comment.message, "\n")
          for _, comment_line in ipairs(comment_lines) do
            table.insert(lines, "  " .. comment_line)
          end
          table.insert(lines, "")
        end
        table.insert(lines, "")
      end
    end
    
    if not has_drafts then
      table.insert(lines, "No draft comments")
    else
      table.insert(lines, "Use :GerritReview to publish draft comments")
    end
    
    table.insert(lines, "")
    table.insert(lines, "Press 'q' to close")
    
    -- Create floating window
    local buf, win = utils.create_centered_float(0.8, 0.8, "Draft Comments")
    utils.set_buffer_content(buf, lines)
    utils.setup_temp_buffer(buf, "gerrit-drafts")
    
    -- Close on 'q'
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<CR>', 
      { noremap = true, silent = true })
    
    -- Register buffer
    local gerrit = require('gerrit')
    gerrit.register_buffer(buf)
    
    utils.clear_echo()
  end)
end

-- Auto-refresh comments when entering diff buffers
function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup("GerritComments", { clear = true })
  
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "gerrit://diff/*",
    callback = function()
      local buf_name = vim.api.nvim_buf_get_name(0)
      local change_id = buf_name:match("gerrit://diff/([^/]+)/")
      if change_id then
        M.load_comments(change_id)
      end
    end
  })
end

-- Get current comment state (for debugging)
function M.get_state()
  return comment_state
end

return M