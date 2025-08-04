# Testing Gerrit.nvim Plugin

## Setup Complete!

✅ **Neovim**: v0.11.3 installed  
✅ **Plugin Manager**: LazyVim with lazy.nvim configured  
✅ **Plugin**: gerrit.nvim configured at `/Users/anujvarma/.config/nvim/lua/plugins/gerrit.lua`  
✅ **Server**: Configured for `https://gerrit.thumbtack.io`

## How to Test

### 1. Launch Neovim
```bash
nvim
```

### 2. Test Plugin Loading
In Neovim, run:
```vim
:lua print("Testing Gerrit plugin...")
:lua require("gerrit").health()
```

### 3. Check Available Commands
Try these commands:
```vim
:GerritHealth
:GerritConfig  
:GerritList
```

### 4. Test Connection (Anonymous)
```vim
:GerritList
```
This should show public changes from gerrit.thumbtack.io (if any are visible without authentication).

### 5. Configuration for Authenticated Access
To access your changes, you'll need to update the configuration in:
`~/.config/nvim/lua/plugins/gerrit.lua`

Add your authentication:
```lua
-- Option 1: HTTP Password Token (recommended)
auth_token = "your-http-password-token-here",

-- OR Option 2: Username/Password
username = "your-username",
password = "your-password",
```

### 6. Get HTTP Password Token
1. Go to https://gerrit.thumbtack.io
2. Navigate to **Settings** → **HTTP Credentials**
3. Generate a new HTTP password token
4. Add it to your config

### 7. Full Workflow Test (with authentication)
```vim
:GerritList                    " List your pending reviews
" Press Enter on a change to open it
:GerritDiff path/to/file.py   " View diff for a specific file
" In diff view:
" - Press 'gc' to add comment
" - Press ']f' / '[f' to navigate files
" - Press ']h' / '[h' to navigate hunks
:GerritApprove "LGTM!"       " Approve change
:GerritReject "Needs work"   " Reject change
```

## Keybindings

### Global (available anywhere in Neovim)
- `<leader>gl` - List Gerrit changes
- `<leader>gh` - Check Gerrit health
- `<leader>gc` - Show Gerrit config

### Change List Window
- `<CR>` - Open selected change
- `r` - Refresh list
- `q` - Close window

### Diff View Window
- `]f` / `[f` - Next/previous file
- `]h` / `[h` - Next/previous hunk  
- `gc` - Add comment at cursor
- `gC` - Toggle comments display

## Troubleshooting

### "Plugin not initialized"
Make sure you have proper authentication configured or the server allows anonymous access.

### "curl not found"
Install curl:
```bash
brew install curl
```

### "Connection failed" 
1. Check if you can access the server in browser
2. Verify your authentication credentials
3. Check if you're behind a corporate firewall

### "No changes found"
- You might not have any pending reviews
- Try different query parameters: `:GerritList status:open`
- Check if authentication is working: `:GerritHealth`

## Next Steps

1. **Add Authentication**: Update config with your Gerrit credentials
2. **Test Full Workflow**: Try reviewing an actual change
3. **Customize**: Adjust keybindings and UI settings to your preference
4. **Integration**: Add to your daily workflow

Enjoy code reviewing from within Neovim! 🚀