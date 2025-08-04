# gerrit.nvim

A comprehensive Neovim plugin for Gerrit code review integration, allowing you to review code directly from your editor.

![Neovim](https://img.shields.io/badge/neovim-0.7+-green?style=flat-square)
![Lua](https://img.shields.io/badge/lua-5.1+-blue?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-orange?style=flat-square)

## Features

- 🔍 **Browse Changes**: List and filter pending changes
- 📊 **Diff Viewing**: View file diffs with syntax highlighting
- 💬 **Comment System**: Add inline comments with virtual text display
- ✅ **Review Workflow**: Approve/reject changes with scores
- 🚀 **Fast Navigation**: Keyboard shortcuts for efficient reviewing
- 🎨 **Customizable UI**: Configurable windows, highlights, and keymaps
- 🔐 **Secure Auth**: Support for authentication tokens and credentials

## Requirements

- Neovim 0.7+
- `curl` (for HTTP requests)
- Access to a Gerrit server

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "anujvarma/gerrit.nvim", -- Replace with actual repository
  config = function()
    require("gerrit").setup({
      server_url = "https://your-gerrit-server.com",
      auth_token = "your-auth-token", -- Or use username/password
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "anujvarma/gerrit.nvim", -- Replace with actual repository
  config = function()
    require("gerrit").setup({
      server_url = "https://your-gerrit-server.com",
      auth_token = "your-auth-token",
    })
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'anujvarma/gerrit.nvim'

lua << EOF
require("gerrit").setup({
  server_url = "https://your-gerrit-server.com",
  auth_token = "your-auth-token",
})
EOF
```

## Configuration

### Basic Setup

```lua
require("gerrit").setup({
  server_url = "https://your-gerrit-server.com",
  
  -- Authentication (choose one method)
  auth_token = "your-http-password-token", -- Recommended
  -- OR
  username = "your-username",
  password = "your-password",
  
  -- Query settings
  query = {
    status = "open",
    is_reviewer = true,
  },
  
  -- UI configuration
  ui = {
    window = {
      width = 0.8,
      height = 0.8,
    },
    diff = {
      context_lines = 3,
      syntax_highlight = true,
    },
    comments = {
      show_resolved = false,
      virtual_text = true,
    },
  },
})
```

### Full Configuration

```lua
require("gerrit").setup({
  -- Required: Gerrit server URL (without trailing slash)
  server_url = "https://gerrit.example.com",
  
  -- Authentication: Use either auth_token (recommended) or username/password
  auth_token = "", -- HTTP password token from Gerrit settings
  username = "",   -- Your Gerrit username
  password = "",   -- Your Gerrit password
  
  -- Query parameters for listing changes
  query = {
    status = "open",        -- Change status: open, merged, abandoned
    is_reviewer = true,     -- Only changes where you're a reviewer
    -- Additional query parameters:
    -- project = "my-project",
    -- owner = "username",
    -- reviewer = "username",
  },
  
  -- UI settings
  ui = {
    -- Window dimensions (as fraction of screen size)
    window = {
      width = 0.8,
      height = 0.8,
    },
    
    -- Diff view settings
    diff = {
      context_lines = 3,
      syntax_highlight = true,
    },
    
    -- Comment display settings
    comments = {
      show_resolved = false,  -- Show resolved comments
      virtual_text = true,    -- Display comments as virtual text
    },
  },
  
  -- Key mappings
  mappings = {
    -- Change list window
    change_list = {
      open_change = "<CR>",
      refresh = "r",
      quit = "q",
    },
    
    -- Diff view window
    diff_view = {
      next_file = "]f",
      prev_file = "[f",
      next_hunk = "]h",
      prev_hunk = "[h",
      add_comment = "gc",
      toggle_comments = "gC",
    },
  },
})
```

## Authentication Setup

### Method 1: HTTP Password Token (Recommended)

1. Go to your Gerrit server: `https://your-gerrit-server.com`
2. Navigate to **Settings** → **HTTP Credentials**
3. Generate a new HTTP password token
4. Use this token in your configuration:

```lua
require("gerrit").setup({
  server_url = "https://your-gerrit-server.com",
  auth_token = "your-generated-token",
})
```

### Method 2: Username/Password

```lua
require("gerrit").setup({
  server_url = "https://your-gerrit-server.com",
  username = "your-username",
  password = "your-password",
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:GerritList [query]` | List changes (with optional query parameters) |
| `:GerritOpen <change-id>` | Open a specific change |
| `:GerritDiff [file]` | Show diff for a file |
| `:GerritComment` | Add comment at cursor position |
| `:GerritApprove [message]` | Approve change (+2) |
| `:GerritReject [message]` | Reject change (-2) |
| `:GerritReview <score> [message]` | Submit review with score (-2 to +2) |
| `:GerritRefresh` | Refresh current view |
| `:GerritConfig` | Show current configuration |
| `:GerritHealth` | Check plugin health |

### Query Examples

```vim
" List all open changes where you're a reviewer
:GerritList

" List changes in a specific project
:GerritList project:my-project

" List merged changes
:GerritList status:merged

" List changes by a specific owner
:GerritList owner:username

" Combine multiple query parameters
:GerritList project:my-project status:open
```

### Workflow Example

1. **List changes to review**:
   ```vim
   :GerritList
   ```

2. **Open a specific change**:
   ```vim
   :GerritOpen 12345
   ```

3. **View diff for a file**:
   ```vim
   :GerritDiff path/to/file.py
   ```

4. **Add comments** (in diff view):
   - Position cursor on the line you want to comment on
   - Press `gc` or run `:GerritComment`
   - Enter your comment text

5. **Submit review**:
   ```vim
   :GerritApprove "Looks good to me!"
   " or
   :GerritReview 1 "Minor suggestions, but overall good"
   " or
   :GerritReject "Needs significant changes"
   ```

### Key Bindings

#### Change List Window
- `<CR>` - Open selected change
- `r` - Refresh change list
- `q` - Close window

#### Diff View Window
- `]f` / `[f` - Next/previous file
- `]h` / `[h` - Next/previous hunk
- `gc` - Add comment at cursor
- `gC` - Toggle comments display

## File Types

The plugin creates several custom file types:
- `gerrit-changes` - Change list buffer
- `gerrit-change` - Change detail buffer
- `gerrit-diff` - Diff view buffer
- `gerrit-comments` - Comments list buffer

## Health Check

Run `:GerritHealth` to check:
- Plugin initialization status
- Server configuration
- Authentication setup
- Required dependencies (curl)

## Troubleshooting

### Connection Issues

1. **Check server URL**: Ensure the URL is correct and accessible
   ```vim
   :GerritConfig
   ```

2. **Verify authentication**: Test your credentials outside of Neovim
   ```bash
   curl -u username:token https://your-gerrit-server.com/a/accounts/self
   ```

3. **Check health status**:
   ```vim
   :GerritHealth
   ```

### Common Problems

- **"Plugin not initialized"**: Run `:lua require('gerrit').setup({...})` with proper configuration
- **"Authentication failed"**: Check your auth_token or username/password
- **"curl not found"**: Install curl on your system
- **SSL certificate issues**: Your Gerrit server may have SSL configuration issues

### Debug Information

To get debug information:
```lua
:lua vim.print(require('gerrit').get_state())
```

## API Reference

The plugin exposes a Lua API for programmatic use:

```lua
local gerrit = require('gerrit')

-- Setup the plugin
gerrit.setup(config)

-- List changes
gerrit.list_changes({ project = "my-project" })

-- Open a specific change
gerrit.open_change("12345")

-- Show diff for a file
gerrit.show_diff("path/to/file.py")

-- Add comment
gerrit.add_comment()

-- Submit review
gerrit.submit_review(2, "Approved!")
```

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### Development

1. Clone the repository
2. Make your changes
3. Test with a local Gerrit instance
4. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Built with ❤️ for the Neovim community
- Inspired by other code review integrations
- Thanks to the Gerrit project for providing excellent REST API documentation