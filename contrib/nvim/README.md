# oxybelis.nvim — Neovim plugin for Oxybelis

## Quick Start

### Using lazy.nvim

```lua
{
  dir = "~/Projects/oxybelis/contrib/nvim",
  -- or: "oxybelis-lang/oxybelis" if published as a plugin
  ft = "ox",
  opts = {},
}
```

### Manual install

Copy the files into your Neovim config:

```bash
# Unix
cp -r contrib/nvim/* ~/.config/nvim/

# PowerShell (Windows)
Copy-Item -Recurse contrib\nvim\* "$env:LOCALAPPDATA\nvim\"
```

Then add to your `init.lua`:

```lua
require("oxybelis").setup()
```

## Requirements

- Neovim >= 0.9 (for `vim.lsp.start`)
- `ox-lsp` on PATH (installed via Oxybelis install script or `pip install oxybelis`)

## Features

- Automatic LSP client for `.ox` files
- Diagnostics, hover, goto-definition, completions
- Code formatting via `ox-fmt`
- Basic syntax highlighting
- Filetype detection

## Configuration

```lua
require("oxybelis").setup({
  on_attach = function(client, bufnr)
    -- Your custom keymaps here
  end,
  capabilities = {}, -- extra LSP capabilities
})
```
