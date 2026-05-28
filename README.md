# Oxybelis

A statically-typed, Python-inspired language that transpiles to C++.

```
let msg: str = "Hello from Oxybelis!"
print(msg)
```

## Quick Install

**Windows** (PowerShell):
```powershell
irm https://oxybelis.dev/install.ps1 | iex
```

**Unix** (Linux/macOS):
```bash
curl -fsSL https://oxybelis.dev/install.sh | sh
```

Installs native `oxybelis`, `ox-fmt`, and `ox-lsp` binaries to `~/.oxybelis/bin/` and adds them to PATH.

Or via package managers (once submitted):
- Homebrew: `brew tap oxybelis-lang/oxybelis && brew install oxybelis`
- Scoop: `scoop install oxybelis`
- AUR: `paru -S oxybelis`

## Manual Install (requires Python)

```bash
uv pip install --system .  # then: oxybelis --help
# or directly:
python oxybelis.py example.ox
```

## Usage

```bash
oxybelis example.ox           # transpile & compile → example.exe
oxybelis example.ox --check   # type-check only
oxybelis example.ox --fmt     # format source in-place
oxybelis example.ox --highlight  # syntax-highlighted source
ox-fmt example.ox             # format file
ox-fmt example.ox --check     # check formatting
ox-lsp                        # LSP server (for VS Code, neovim)
```

## Language Features

- Python-inspired syntax with `{}` blocks
- Static typing: `int`, `float`, `bool`, `str`, `void`, generics
- Classes with fields and methods
- Pattern matching with ranges
- Null safety via `Option<T>`
- `let` (immutable) / `var` (mutable)
- Self-hosting compiler in `compiler.ox`

## Self-Hosting

```
compiler.ox  ──[oxybelis]──→ compiler.cpp ──[g++]──→ compiler.exe
```

## Project Structure

| File | Purpose |
|---|---|
| `oxybelis.py` | Python reference transpiler + type checker |
| `ox_fmt.py` | Code formatter |
| `ox_lsp.py` | LSP server (zero deps) |
| `ox_diag.py` | Diagnostic types and renderer |
| `compiler.ox` | Self-hosting compiler source |
| `build.py` | Build native binaries via Nuitka |
| `install.ps1` / `install.sh` | Cross-platform installers |
| `pyproject.toml` | Python package metadata |
| `extension/` | VS Code extension |
| `contrib/` | Package manager recipes (brew, scoop, aur) |

## Type Checking

```bash
oxybelis file.ox --check
```

Produces Rust-style diagnostics with error codes (E0308, E0425, E0060, etc.).

## License

GNU General Public License v3.0
