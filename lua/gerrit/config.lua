local M = {}

-- Default configuration
M.defaults = {
  server_url = "",
  username = "",
  password = "",
  -- Authentication token (preferred over username/password)
  auth_token = "",
  -- Query parameters for listing changes
  query = {
    status = "open",
    is_reviewer = true,
  },
  -- UI settings
  ui = {
    -- Window settings
    window = {
      width = 0.8,
      height = 0.8,
    },
    -- Diff settings
    diff = {
      context_lines = 3,
      syntax_highlight = true,
    },
    -- Comment settings
    comments = {
      show_resolved = false,
      virtual_text = true,
    },
  },
  -- Key mappings
  mappings = {
    -- Change list mappings
    change_list = {
      open_change = "<CR>",
      refresh = "r",
      quit = "q",
    },
    -- Diff view mappings
    diff_view = {
      next_file = "]f",
      prev_file = "[f",
      next_hunk = "]h",
      prev_hunk = "[h",
      add_comment = "gc",
      toggle_comments = "gC",
    },
  },
}

-- User configuration storage
M.config = {}

-- Setup function to merge user config with defaults
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
  
  -- Validate required settings
  if not M.config.server_url or M.config.server_url == "" then
    vim.api.nvim_err_writeln("gerrit.nvim: server_url is required")
    return false
  end
  
  -- Ensure server_url doesn't end with slash
  M.config.server_url = M.config.server_url:gsub("/$", "")
  
  -- Note: Authentication is optional for public Gerrit servers
  -- Anonymous access will be used if no authentication is provided
  
  return true
end

-- Get current configuration
function M.get()
  return M.config
end

-- Get authentication headers
function M.get_auth_header()
  if M.config.auth_token and M.config.auth_token ~= "" then
    return "Authorization: Bearer " .. M.config.auth_token
  elseif M.config.username and M.config.password then
    local credentials = vim.base64.encode(M.config.username .. ":" .. M.config.password)
    return "Authorization: Basic " .. credentials
  end
  return nil
end

-- Get API base URL (with /a/ prefix for authenticated requests)
function M.get_api_url()
  local auth_header = M.get_auth_header()
  if auth_header then
    return M.config.server_url .. "/a"
  else
    return M.config.server_url
  end
end

return M