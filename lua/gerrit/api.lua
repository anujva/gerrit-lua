local config = require('gerrit.config')
local utils = require('gerrit.utils')

local M = {}

-- Remove Gerrit's magic prefix from JSON responses
local function strip_magic_prefix(response)
  -- Gerrit responses start with )]}'<newline> (5 characters total)
  if response:sub(1, 5) == ")]}'\n" then
    return response:sub(6)
  end
  return response
end

-- Make HTTP request to Gerrit API
local function make_request(endpoint, method, data, callback)
  method = method or "GET"
  local conf = config.get()
  local url = config.get_api_url() .. endpoint
  local auth_header = config.get_auth_header()
  
  local curl_args = {
    "curl",
    "-s",
    "-X", method,
    "-H", "Content-Type: application/json",
  }
  
  -- Add authentication header
  if auth_header then
    table.insert(curl_args, "-H")
    table.insert(curl_args, auth_header)
  end
  
  -- Add data for POST/PUT requests
  if data and (method == "POST" or method == "PUT") then
    table.insert(curl_args, "-d")
    table.insert(curl_args, vim.json.encode(data))
  end
  
  table.insert(curl_args, url)
  
  local function on_exit(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        callback(nil, "HTTP request failed: " .. (obj.stderr or "Unknown error"))
        return
      end
      
      local response_body = strip_magic_prefix(obj.stdout)
      
      local success, result = pcall(vim.json.decode, response_body)
      
      if not success then
        callback(nil, "Failed to parse JSON response: " .. result)
        return
      end
      
      callback(result, nil)
    end)
  end
  
  vim.system(curl_args, { text = true }, on_exit)
end

-- Query changes from Gerrit
function M.query_changes(query_params, callback)
  local params = vim.tbl_extend("force", config.get().query, query_params or {})
  
  -- Build Gerrit query string (uses q= parameter)
  local query_parts = {}
  for key, value in pairs(params) do
    if type(value) == "boolean" then
      if value then
        if key == "is_reviewer" then
          table.insert(query_parts, "is:reviewer")
        else
          table.insert(query_parts, key)
        end
      end
    else
      table.insert(query_parts, key .. ":" .. tostring(value))
    end
  end
  
  local query_string = ""
  if #query_parts > 0 then
    query_string = "?q=" .. vim.uri_encode(table.concat(query_parts, " "))
  end
  
  make_request("/changes/" .. query_string, "GET", nil, callback)
end

-- Get detailed information about a specific change
function M.get_change_detail(change_id, callback)
  local endpoint = "/changes/" .. vim.uri_encode(change_id) .. "?o=CURRENT_REVISION&o=CURRENT_FILES&o=DETAILED_LABELS&o=MESSAGES"
  make_request(endpoint, "GET", nil, callback)
end

-- Get revision information for a change
function M.get_revision(change_id, revision_id, callback)
  revision_id = revision_id or "current"
  local endpoint = "/changes/" .. vim.uri_encode(change_id) .. "/revisions/" .. vim.uri_encode(revision_id)
  make_request(endpoint, "GET", nil, callback)
end

-- Get file content for a specific revision
function M.get_file_content(change_id, revision_id, file_path, callback)
  revision_id = revision_id or "current"
  local endpoint = "/changes/" .. vim.uri_encode(change_id) .. "/revisions/" .. vim.uri_encode(revision_id) .. "/files/" .. vim.uri_encode(file_path) .. "/content"
  
  -- File content endpoint returns base64 encoded content, not JSON
  local conf = config.get()
  local url = config.get_api_url() .. endpoint
  local auth_header = config.get_auth_header()
  
  local curl_args = {
    "curl",
    "-s",
    "-H", "Content-Type: application/json",
  }
  
  if auth_header then
    table.insert(curl_args, "-H")
    table.insert(curl_args, auth_header)
  end
  
  table.insert(curl_args, url)
  
  local function on_exit(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        callback(nil, "HTTP request failed: " .. (obj.stderr or "Unknown error"))
        return
      end
      
      -- Decode base64 content
      local success, decoded = pcall(vim.base64.decode, obj.stdout)
      if not success then
        callback(nil, "Failed to decode file content")
        return
      end
      
      callback(decoded, nil)
    end)
  end
  
  vim.system(curl_args, { text = true }, on_exit)
end

-- Get diff for a file
function M.get_file_diff(change_id, revision_id, file_path, callback)
  -- Always use "current" for diff requests as revision hashes don't seem to work
  revision_id = "current"
  
  -- change_id should now be the change number (not the full ID)
  -- Note: vim.uri_encode might not encode '/' characters, so let's do manual encoding
  local encoded_file_path = file_path:gsub("/", "%%2F")
  local endpoint = "/changes/" .. tostring(change_id) .. "/revisions/" .. revision_id .. "/files/" .. encoded_file_path .. "/diff"
  
  
  make_request(endpoint, "GET", nil, callback)
end

-- Get comments for a change
function M.get_comments(change_id, callback)
  local endpoint = "/changes/" .. vim.uri_encode(change_id) .. "/comments"
  make_request(endpoint, "GET", nil, callback)
end

-- Get draft comments for a change
function M.get_draft_comments(change_id, callback)
  local endpoint = "/changes/" .. vim.uri_encode(change_id) .. "/drafts"
  make_request(endpoint, "GET", nil, callback)
end

-- Add a comment to a change
function M.add_draft_comment(change_id, revision_id, file_path, line, message, callback)
  revision_id = revision_id or "current"
  local endpoint = "/changes/" .. vim.uri_encode(change_id) .. "/revisions/" .. vim.uri_encode(revision_id) .. "/drafts"
  
  local comment_data = {
    path = file_path,
    line = line,
    message = message,
  }
  
  make_request(endpoint, "PUT", comment_data, callback)
end

-- Submit a review
function M.submit_review(change_id, revision_id, review_data, callback)
  revision_id = revision_id or "current"
  local endpoint = "/changes/" .. vim.uri_encode(change_id) .. "/revisions/" .. vim.uri_encode(revision_id) .. "/review"
  make_request(endpoint, "POST", review_data, callback)
end

-- Get current user account information
function M.get_account_info(callback)
  make_request("/accounts/self", "GET", nil, callback)
end

-- Test connection to Gerrit server
function M.test_connection(callback)
  M.get_account_info(function(result, error)
    if error then
      callback(false, error)
    else
      callback(true, "Connected as " .. (result.name or result.username or result.email or "unknown user"))
    end
  end)
end

return M