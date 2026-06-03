# Oxybelis

A statically-typed, Python-inspired language that transpiles to C++.

```rust
fn main() -> void {
    let msg: str = "Hello from Oxybelis!"
    print(msg)
}
```

## Quick Start

**Prerequisites:** A C++ compiler (`g++` on Linux/Windows, `clang++` on macOS).

### Install

```powershell
# Windows (PowerShell)
irm https://raw.githubusercontent.com/oxybelis-lang/oxybelis/main/install.ps1 | iex
```

```bash
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/oxybelis-lang/oxybelis/main/install.sh | sh
```

Installs `oxybelis` to `~/.oxybelis/bin/` and adds it to PATH.

### Run a file

```bash
echo 'fn main() -> void { print("hello world") }' > hello.ox
oxybelis hello.ox
# → compiles + runs, prints "hello world"
```

That's it. No Python, no extra steps. The compiler auto-runs the output.

## Also works with Python

```bash
git clone https://github.com/oxybelis-lang/oxybelis.git
cd oxybelis
python oxybelis.py hello.ox
```

The Python version has a full type checker (`--check`). The bootstrapped compiler (`compiler.ox`) is lighter — no type-checking pass but self-hosting.

## CLI

```bash
oxybelis example.ox              # compile + run
oxybelis -S example.ox           # emit C++ to stdout only
oxybelis -o out.cpp example.ox   # write C++ to file
oxybelis --cc clang++ file.ox    # use a different C++ compiler
oxybelis example.ox --check      # type-check only (Python version)
```

## Language

- Python-inspired syntax with `{}` blocks
- Static typing: `int`, `float`, `bool`, `str`, `void`, generics
- Classes with fields and methods
- Pattern matching with ranges
- Null safety via `Option<T>`
- `Result<T, E>` with `?` operator
- `let` (immutable) / `var` (mutable)
- Standard library: `json`, `collections`, `path`, `fs`
- Self-hosting compiler in `compiler.ox`

## Project Structure

| File | Purpose |
|---|---|
| `oxybelis.py` | Python reference compiler (full type checker) |
| `compiler.ox` | Self-hosting compiler (bootstrap target) |
| `compiler.exe` | Pre-built bootstrapped compiler (in releases) |
| `oxlib/` | Standard library modules |
| `tests/` | Test suite (`python tests/run_tests.py`) |
| `install.ps1` / `install.sh` | Cross-platform installers |

## License

GNU General Public License v3.0
