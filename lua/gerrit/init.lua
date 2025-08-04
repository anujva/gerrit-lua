local config = require('gerrit.config')
local api = require('gerrit.api')
local utils = require('gerrit.utils')

local M = {}

-- Plugin state
local state = {
  initialized = false,
  current_change = nil,
  current_revision = nil,
  buffers = {}, -- Track plugin-managed buffers
}

-- Initialize the plugin
function M.setup(opts)
  if state.initialized then
    utils.show_info("Already initialized")
    return
  end
  
  -- Setup configuration
  if not config.setup(opts) then
    return false
  end
  
  
  -- Test connection to Gerrit
  utils.show_progress("Testing connection to Gerrit")
  api.test_connection(function(success, message)
    if success then
      utils.show_success(message)
      state.initialized = true
      
      -- Setup commands and keymaps
      M.setup_commands()
    else
      utils.show_error("Failed to connect to Gerrit: " .. message)
    end
  end)
  
  return true
end

-- Setup user commands
function M.setup_commands()
  local commands = require('gerrit.commands')
  commands.setup()
end

-- Get current project name from directory
local function get_current_project()
  local cwd = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(cwd, ":t")
  return project_name
end

-- List changes assigned to user
function M.list_changes(query_params)
  if not state.initialized then
    utils.show_error("Plugin not initialized. Run :lua require('gerrit').setup()")
    return
  end
  
  -- Defer execution to avoid conflicts with dashboard cursor management
  vim.schedule(function()
  
  -- Auto-add current project if no project specified and we're in a project directory
  query_params = query_params or {}
  if not query_params.project or query_params.project == nil then
    local current_project = get_current_project()
    if current_project and current_project ~= "" then
      query_params.project = current_project
      utils.show_info("Filtering by project: " .. current_project)
    end
  elseif query_params.project == "" then
    -- Empty string means explicitly disable project filtering
    query_params.project = nil
  end
  
  utils.show_progress("Fetching changes")
  
  api.query_changes(query_params, function(changes, error)
    if error then
      utils.show_error("Failed to fetch changes: " .. error)
      return
    end
    
    if not changes or #changes == 0 then
      utils.show_info("No changes found" .. (query_params.project and " for project: " .. query_params.project or ""))
      return
    end
    
    -- Show changes in UI
    local ui = require('gerrit.ui')
    ui.show_change_list(changes)
  end)
  end) -- Close the vim.schedule
end

-- Open a specific change by ID
function M.open_change(change_id)
  if not state.initialized then
    utils.show_error("Plugin not initialized")
    return
  end
  
  utils.show_progress("Loading change details")
  
  api.get_change_detail(change_id, function(change, error)
    if error then
      utils.show_error("Failed to load change: " .. error)
      return
    end
    
    state.current_change = change
    state.current_revision = change.current_revision
    
    -- Show change details
    local ui = require('gerrit.ui')
    ui.show_change_detail(change)
  end)
end

-- Show diff for a file in the current change
function M.show_diff(file_path)
  if not state.current_change then
    utils.show_error("No change selected")
    return
  end
  
  local diff_module = require('gerrit.diff')
  diff_module.show_file_diff(state.current_change.id, state.current_revision, file_path)
end

-- Add comment at current cursor position
function M.add_comment()
  if not state.current_change then
    utils.show_error("No change selected")
    return
  end
  
  local comments_module = require('gerrit.comments')
  comments_module.add_comment_at_cursor(state.current_change.id, state.current_revision)
end

-- Submit review for current change
function M.submit_review(score, message)
  if not state.current_change then
    utils.show_error("No change selected")
    return
  end
  
  local review_data = {
    message = message or "",
    labels = {}
  }
  
  -- Add Code-Review score if provided
  if score then
    review_data.labels["Code-Review"] = score
  end
  
  utils.show_progress("Submitting review")
  
  api.submit_review(state.current_change.id, state.current_revision, review_data, function(result, error)
    if error then
      utils.show_error("Failed to submit review: " .. error)
      return
    end
    
    utils.show_success("Review submitted successfully")
  end)
end

-- Get current plugin state (for debugging)
function M.get_state()
  return state
end

-- Clean up plugin resources
function M.cleanup()
  -- Close plugin-managed buffers
  for buf_id, _ in pairs(state.buffers) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      vim.api.nvim_buf_delete(buf_id, { force = true })
    end
  end
  
  state.buffers = {}
  state.current_change = nil
  state.current_revision = nil
end

-- Register a buffer as plugin-managed
function M.register_buffer(buf)
  state.buffers[buf] = true
end

-- Unregister a plugin-managed buffer
function M.unregister_buffer(buf)
  state.buffers[buf] = nil
end

-- Health check function
function M.health()
  local health_start = vim.health and vim.health.start or vim.health.report_start
  local health_ok = vim.health and vim.health.ok or vim.health.report_ok
  local health_warn = vim.health and vim.health.warn or vim.health.report_warn
  local health_error = vim.health and vim.health.error or vim.health.report_error
  
  health_start("gerrit.nvim")
  
  -- Check if initialized
  if state.initialized then
    health_ok("Plugin initialized")
  else
    health_warn("Plugin not initialized")
  end
  
  -- Check configuration
  local conf = config.get()
  if conf.server_url and conf.server_url ~= "" then
    health_ok("Server URL configured: " .. conf.server_url)
  else
    health_error("Server URL not configured")
  end
  
  if conf.auth_token and conf.auth_token ~= "" then
    health_ok("Authentication token configured")
  elseif conf.username and conf.username ~= "" and conf.password and conf.password ~= "" then
    health_ok("Username/password configured")
  else
    health_error("No authentication method configured")
  end
  
  -- Check dependencies
  if vim.fn.executable('curl') == 1 then
    health_ok("curl is available")
  else
    health_error("curl is not available (required for API requests)")
  end
end

return M