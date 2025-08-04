-- Test script for gerrit.nvim plugin
print("=== Testing Gerrit.nvim Plugin ===")

-- Load the plugin
local gerrit = require("gerrit")

-- Setup with Thumbtack server
print("Setting up Gerrit plugin...")
local setup_success = gerrit.setup({
  server_url = "https://gerrit.thumbtack.io",
  -- No authentication for initial testing
})

if setup_success == false then
  print("❌ Plugin setup failed!")
  return
end

print("✅ Plugin setup completed successfully")

-- Test health check
print("\n=== Health Check ===")
gerrit.health()

-- Test plugin state
print("\n=== Plugin State ===")
local state = gerrit.get_state()
print("Initialized:", state.initialized)
print("Current change:", state.current_change or "none")

print("\n=== Available Commands ===")
print("The following commands should be available:")
print("- :GerritList")
print("- :GerritOpen <change-id>")
print("- :GerritDiff [file]")
print("- :GerritComment")
print("- :GerritApprove [message]")
print("- :GerritReject [message]")
print("- :GerritHealth")
print("- :GerritConfig")

print("\n=== Test Completed ===")
print("You can now test the plugin by running :GerritList in Neovim")
print("Note: Without authentication, you'll only see public changes")