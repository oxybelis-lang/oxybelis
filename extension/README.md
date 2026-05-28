# Oxybelis VS Code Extension

A complete VS Code extension for the **Oxybelis** language with LSP support, type checking, syntax highlighting, and more.

## Features

✨ **Full Language Support**
- **Syntax Highlighting** – Semantic tokens via LSP for accurate highlighting
- **Type Checking** – Real-time diagnostics with Rust-style error messages
- **Hover Information** – Type hints and documentation on hover
- **Code Completion** – Autocomplete for builtins, functions, and local symbols
- **Go to Definition** – Jump to function and class definitions
- **Diagnostics** – Live error reporting as you type

⚙️ **Developer Tools**
- **Transpile Command** – Convert `.ox` to C++
- **Build Command** – One-click transpile + compile
- **Type Check Command** – Validate types before building
- **Format Command** – Code formatting (coming soon)

🚀 **Integration**
- Connects to `ox_lsp.py` language server (zero external dependencies)
- Works with the existing Oxybelis toolchain
- Configure paths to Python and compiler in settings

## Installation

### From Source

1. Clone the repository
2. Navigate to the `extension` directory
3. Install dependencies:
   ```bash
   npm install
   ```

4. Compile TypeScript:
   ```bash
   npm run compile
   ```

5. In VS Code, press `F1` and run:
   ```
   Extensions: Install from VSIX
   ```
   Or open `extension.vsix` after packaging

### Development Mode

1. Open the `extension` folder in VS Code
2. Press `F5` to launch the extension host
3. Test with `.ox` files in the debug window

## Configuration

Open VS Code settings and search for `oxybelis`:

```json
{
  "oxybelis.lsp.enable": true,
  "oxybelis.lsp.pythonPath": "python",
  "oxybelis.lsp.serverPath": "../ox_lsp.py",
  
  "oxybelis.typeCheck.enable": true,
  
  "oxybelis.compiler.pythonPath": "python",
  "oxybelis.compiler.oxybelisPath": "../oxybelis.py"
}
```

### Path Resolution

- **Relative paths** like `../ox_lsp.py` are resolved relative to the extension directory
- **Absolute paths** are used as-is
- **Command names** like `python` are searched in `$PATH`

## Commands

| Command | Keybinding | Description |
|---------|-----------|-------------|
| `oxybelis.transpile` | `Ctrl+Shift+B` | Transpile current file to C++ |
| `oxybelis.build` | — | Transpile + compile to executable |
| `oxybelis.check` | — | Type check current file |
| `oxybelis.format` | — | Format current file |
| `oxybelis.highlight` | — | Show syntax highlighting |

## Troubleshooting

### "Language server failed to start"

1. Check that Python is installed and accessible:
   ```bash
   python --version
   ```

2. Verify `ox_lsp.py` exists at the configured path:
   ```bash
   python ox_lsp.py
   ```

3. Check VS Code output channel (`View → Output → Oxybelis`) for errors

### Hover info not appearing

- Ensure `oxybelis.lsp.enable` is `true`
- Check that the LSP server started (see Output channel)
- Try reloading the window: `Ctrl+Shift+P` → `Developer: Reload Window`

### Transpile command fails

1. Verify Python is in `$PATH` or set `oxybelis.compiler.pythonPath`
2. Check `oxybelis.compiler.oxybelisPath` points to `oxybelis.py`
3. Try running manually: `python oxybelis.py file.ox`

## Development

### Building from Source

```bash
# Install dependencies
npm install

# Compile TypeScript
npm run compile

# Watch for changes (development)
npm run watch

# Lint code
npm run lint
```

### Extension Structure

```
extension/
├── src/
│   └── extension.ts         # Main extension code
├── syntaxes/
│   └── oxybelis.tmLanguage.json  # TextMate grammar
├── language-configuration.json   # Language settings
├── package.json             # Extension manifest
└── tsconfig.json            # TypeScript config
```

### Key Components

- **Extension Host** – VS Code integration, command registration
- **Language Client** – Communicates with LSP server
- **Commands** – Transpile, build, type check, format
- **Grammar** – TextMate syntax for `.ox` files

## Requirements

- **VS Code** 1.80.0+
- **Python** 3.8+
- **Language Server** – `ox_lsp.py` in the parent directory
- **Compiler** – `oxybelis.py` + g++ (for build command)

## Related

- [Oxybelis Language](../README.md)
- [Language Specification](../SPEC.md)
- [Language Server](../ox_lsp.py)
- [Reference Compiler](../oxybelis.py)

## License

Same as Oxybelis project
