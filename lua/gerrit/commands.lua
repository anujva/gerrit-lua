local config = require('gerrit.config')
local utils = require('gerrit.utils')

local M = {}

-- Setup user commands
function M.setup()
  -- Main commands
  vim.api.nvim_create_user_command('GerritList', function(opts)
    local gerrit = require('gerrit')
    local query_params = {}
    
    -- Parse arguments for filtering
    if opts.args and opts.args ~= "" then
      -- Simple parsing for common query parameters
      for param in opts.args:gmatch("%S+") do
        if param:match("^project:") then
          query_params.project = param:gsub("^project:", "")
        elseif param:match("^status:") then
          query_params.status = param:gsub("^status:", "")
        elseif param:match("^owner:") then
          query_params.owner = param:gsub("^owner:", "")
        elseif param:match("^reviewer:") then
          query_params.reviewer = param:gsub("^reviewer:", "")
        end
      end
    end
    
    gerrit.list_changes(query_params)
  end, {
    nargs = '*',
    desc = 'List Gerrit changes (auto-filters by current project)',
    complete = function()
      return {
        'status:open',
        'status:merged',
        'status:abandoned',
        'project:',
        'owner:',
        'reviewer:',
      }
    end
  })
  
  vim.api.nvim_create_user_command('GerritListAll', function(opts)
    local gerrit = require('gerrit')
    local query_params = { project = nil } -- Force no project filtering
    
    -- Parse arguments for filtering
    if opts.args and opts.args ~= "" then
      for param in opts.args:gmatch("%S+") do
        if param:match("^project:") then
          query_params.project = param:gsub("^project:", "")
        elseif param:match("^status:") then
          query_params.status = param:gsub("^status:", "")
        elseif param:match("^owner:") then
          query_params.owner = param:gsub("^owner:", "")
        elseif param:match("^reviewer:") then
          query_params.reviewer = param:gsub("^reviewer:", "")
        end
      end
    end
    
    -- Force disable automatic project filtering
    if query_params.project == nil then
      query_params.project = "" -- Empty string to prevent auto-detection
    end
    
    gerrit.list_changes(query_params)
  end, {
    nargs = '*',
    desc = 'List all Gerrit changes (no project filtering)',
    complete = function()
      return {
        'status:open',
        'status:merged', 
        'status:abandoned',
        'project:',
        'owner:',
        'reviewer:',
      }
    end
  })
  
  vim.api.nvim_create_user_command('GerritOpen', function(opts)
    if not opts.args or opts.args == "" then
      utils.show_error("Change ID required. Usage: :GerritOpen <change-id>")
      return
    end
    
    local gerrit = require('gerrit')
    gerrit.open_change(opts.args)
  end, {
    nargs = 1,
    desc = 'Open a specific Gerrit change',
  })
  
  vim.api.nvim_create_user_command('GerritDiff', function(opts)
    local gerrit = require('gerrit')
    local file_path = opts.args
    
    -- If no file path provided, use current buffer
    if not file_path or file_path == "" then
      file_path = vim.api.nvim_buf_get_name(0)
      if file_path == "" then
        utils.show_error("No file path provided and current buffer has no name")
        return
      end
      -- Get relative path from full path
      file_path = vim.fn.fnamemodify(file_path, ':.')
    end
    
    gerrit.show_diff(file_path)
  end, {
    nargs = '?',
    desc = 'Show diff for a file in current change',
    complete = 'file',
  })
  
  vim.api.nvim_create_user_command('GerritComment', function()
    local gerrit = require('gerrit')
    gerrit.add_comment()
  end, {
    nargs = 0,
    desc = 'Add comment at cursor position',
  })
  
  vim.api.nvim_create_user_command('GerritApprove', function(opts)
    local gerrit = require('gerrit')
    local message = opts.args or ""
    gerrit.submit_review(2, message) -- +2 approval
  end, {
    nargs = '*',
    desc = 'Approve current change (+2)',
  })
  
  vim.api.nvim_create_user_command('GerritReject', function(opts)
    local gerrit = require('gerrit')
    local message = opts.args or ""
    gerrit.submit_review(-2, message) -- -2 rejection
  end, {
    nargs = '*',
    desc = 'Reject current change (-2)',
  })
  
  vim.api.nvim_create_user_command('GerritReview', function(opts)
    local args = vim.split(opts.args or "", " ", { trimempty = true })
    local score = tonumber(args[1])
    local message = table.concat(args, " ", 2)
    
    if not score or score < -2 or score > 2 then
      utils.show_error("Invalid score. Usage: :GerritReview <-2|-1|0|1|2> [message]")
      return
    end
    
    local gerrit = require('gerrit')
    gerrit.submit_review(score, message)
  end, {
    nargs = '+',
    desc = 'Submit review with score and optional message',
  })
  
  vim.api.nvim_create_user_command('GerritRefresh', function()
    -- Refresh current view
    local buf = vim.api.nvim_get_current_buf()
    local buf_name = vim.api.nvim_buf_get_name(buf)
    
    if buf_name:match("gerrit://changes") then
      -- Refresh change list
      local gerrit = require('gerrit')
      gerrit.list_changes()
    elseif buf_name:match("gerrit://change/") then
      -- Refresh current change
      local change_id = buf_name:match("gerrit://change/([^/]+)")
      if change_id then
        local gerrit = require('gerrit')
        gerrit.open_change(change_id)
      end
    else
      utils.show_info("Nothing to refresh")
    end
  end, {
    nargs = 0,
    desc = 'Refresh current Gerrit view',
  })
  
  vim.api.nvim_create_user_command('GerritConfig', function()
    local conf = config.get()
    local lines = {
      "Gerrit Configuration:",
      "",
      "Server URL: " .. (conf.server_url or "Not set"),
      "Username: " .. (conf.username or "Not set"),
      "Auth Token: " .. (conf.auth_token and "***" or "Not set"),
      "",
      "Query Settings:",
      "  Status: " .. (conf.query.status or "open"),
      "  Is Reviewer: " .. tostring(conf.query.is_reviewer or false),
    }
    
    -- Create info buffer
    local buf, win = utils.create_centered_float(0.6, 0.4, "Gerrit Configuration")
    utils.set_buffer_content(buf, lines)
    utils.setup_temp_buffer(buf, "text")
    
    -- Close on q or Escape
    local close_keys = { 'q', '<Esc>' }
    for _, key in ipairs(close_keys) do
      vim.api.nvim_buf_set_keymap(buf, 'n', key, '<cmd>close<CR>', 
        { noremap = true, silent = true })
    end
  end, {
    nargs = 0,
    desc = 'Show Gerrit configuration',
  })
  
  vim.api.nvim_create_user_command('GerritHealth', function()
    local gerrit = require('gerrit')
    gerrit.health()
  end, {
    nargs = 0,
    desc = 'Check Gerrit plugin health',
  })
  
  -- Setup filetype-specific keymaps
  M.setup_keymaps()
end

-- Setup key mappings
function M.setup_keymaps()
  local conf = config.get()
  
  -- Create autogroup for Gerrit buffers
  local group = vim.api.nvim_create_augroup("GerritKeymaps", { clear = true })
  
  -- Set up keymaps for change list buffers
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "gerrit-changes",
    callback = function(ev)
      local buf = ev.buf
      local mappings = conf.mappings.change_list
      
      -- Open change
      vim.api.nvim_buf_set_keymap(buf, 'n', mappings.open_change, 
        '<cmd>lua require("gerrit.ui").open_selected_change()<CR>',
        { noremap = true, silent = true, desc = "Open selected change" })
      
      -- Refresh list
      vim.api.nvim_buf_set_keymap(buf, 'n', mappings.refresh,
        '<cmd>GerritRefresh<CR>',
        { noremap = true, silent = true, desc = "Refresh change list" })
      
      -- Quit
      vim.api.nvim_buf_set_keymap(buf, 'n', mappings.quit,
        '<cmd>close<CR>',
        { noremap = true, silent = true, desc = "Close change list" })
    end
  })
  
  -- Set up keymaps for diff view buffers  
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "gerrit-diff",
    callback = function(ev)
      local buf = ev.buf
      local mappings = conf.mappings.diff_view
      
      -- File navigation
      vim.api.nvim_buf_set_keymap(buf, 'n', mappings.next_file,
        '<cmd>lua require("gerrit.diff").next_file()<CR>',
        { noremap = true, silent = true, desc = "Next file" })
        
      vim.api.nvim_buf_set_keymap(buf, 'n', mappings.prev_file,
        '<cmd>lua require("gerrit.diff").prev_file()<CR>',
        { noremap = true, silent = true, desc = "Previous file" })
      
      -- Hunk navigation
      vim.api.nvim_buf_set_keymap(buf, 'n', mappings.next_hunk,
        ']c', -- Use built-in diff navigation
        { noremap = true, silent = true, desc = "Next hunk" })
        
      vim.api.nvim_buf_set_keymap(buf, 'n', mappings.prev_hunk,
        '[c', -- Use built-in diff navigation
        { noremap = true, silent = true, desc = "Previous hunk" })
      
      -- Comment management
      vim.api.nvim_buf_set_keymap(buf, 'n', mappings.add_comment,
        '<cmd>GerritComment<CR>',
        { noremap = true, silent = true, desc = "Add comment" })
        
      vim.api.nvim_buf_set_keymap(buf, 'n', mappings.toggle_comments,
        '<cmd>lua require("gerrit.comments").toggle_comments()<CR>',
        { noremap = true, silent = true, desc = "Toggle comments display" })
    end
  })
end

return M