# Oxybelis v1.0 Roadmap

## P0 — Blocking

### Self-hosting compiler parity (compiler.ox)
- [ ] **Type checker** — mirror `TypeChecker` from `oxybelis.py` into `compiler.ox`
  - Type inference for all expressions
  - Function signature validation
  - Generic type parameter resolution
  - Method dispatch and overload resolution
- [ ] **Rich diagnostics** — structured `Span`/`Diagnostic` types in compiler.ox
  - Multi-line error underlines
  - Severity levels (error, warning, note, help)
  - Error codes (`E0001`, `E0308`, etc.)
  - `--check` flag for type-check-only mode
  - `--highlight` flag
- [ ] **Span tracking in AST** — store source positions in node pool

### Standard library — Strings
- [ ] Add to `oxybelis.py` runtime C++ emit:
  - `str_split(s, delim)` → `List<str>`
  - `str_trim(s)` → `str`
  - `str_trim_start(s)` → `str`
  - `str_trim_end(s)` → `str`
  - `str_replace(s, old, new)` → `str` (first occurrence)
  - `str_replace_all(s, old, new)` → `str`
  - `str_join(list, delim)` → `str`
  - `to_upper(s)` → `str`
  - `to_lower(s)` → `str`
  - `starts_with(s, prefix)` → `bool`
  - `ends_with(s, suffix)` → `bool`
  - `str_repeat(s, n)` → `str`
  - `str_reverse(s)` → `str`
  - `str_find(s, sub)` → `Option<int>` (index of first occurrence)
  - `str_format(fmt, args...)` → `str` (sprintf-style)
- [ ] Mirror all same functions in `compiler.ox` runtime C++ emit

### Standard library — Math
- [ ] Discuss approach: Eigen vs MKL vs custom lightweight
- [ ] Add `random` module:
  - `random_int(min, max)` → `int`
  - `random_float()` → `float`
  - `random_bool()` → `bool`
  - `random_seed(seed)`
- [ ] Add math constants: `PI`, `E`
- [ ] Add missing math functions: `asin`, `acos`, `atan`, `atan2`, `sinh`, `cosh`, `tanh`

### Standard library — JSON (rewrite)
- [ ] Parse JSON objects → `Map<str, JsonValue>`
- [ ] Parse JSON arrays → `List<JsonValue>`
- [ ] `JsonValue` sum type (null, bool, int, float, str, array, object)
- [ ] Serialization: `to_json(value)` → `str`
- [ ] Pretty-printing with indentation control

### Standard library — I/O
- [ ] `input()` / `read_line()` → `str`
- [ ] `eprint(msg)` / `eprintln(msg)` → stderr output
- [ ] `append_file(path, content)` → file append mode
- [ ] `read_file_lines(path)` → `List<str>` (already exists as `read_lines`)
- [ ] `temp_dir()` / `temp_file()` → path utilities

### Standard library — DateTime
- [ ] `now()` → timestamp / DateTime struct
- [ ] `format_datetime(fmt)` → `str`
- [ ] `parse_datetime(s, fmt)` → `Option<DateTime>`
- [ ] Time duration / arithmetic

### Documentation
- [ ] **SPEC.md** — complete language specification:
  - Lexical structure (comments, identifiers, keywords, literals, operators)
  - Syntax (EBNF grammar for every construct)
  - Type system (primitive types, generic types, type inference rules)
  - Expressions (all operator precedence and associativity)
  - Statements and declarations
  - Functions and closures
  - Classes and methods
  - Modules and imports
  - Standard library reference
  - C++ runtime specification
  - Memory model and value semantics
- [ ] **TUTORIAL.md** — "Learn Oxybelis in 30 minutes" step-by-step
- [ ] **Doc comments** — `///` and `/** */` comment parsing and extraction
- [ ] **API reference** — generated docs for `oxlib/` modules
- [ ] **CHANGELOG.md**
- [ ] **CONTRIBUTING.md**

### Error handling
- [ ] `panic(msg)` builtin — prints message and aborts
- [ ] `assert(cond)` / `assert(cond, msg)` builtins
- [ ] `try`/`catch` — graceful error recovery from `?` failures
- [ ] `defer` — scope-exit cleanup

---

## P1 — Important

### Language features
- [ ] **Type aliases** — `type UserId = int`
- [ ] **Lambda expressions** — `|x, y| x + y`
- [ ] **Enums / sum types** — `enum Option<T> { None, Some(T) }` with match destructuring
- [ ] **Ternary expressions** — `x if cond else y`
- [ ] **List comprehensions** — `[x * 2 for x in list if x > 0]`
- [ ] **Operator overloading** — user-defined `+`, `==`, etc.
- [ ] **Tuple types** — `(int, str)` return types, destructuring
- [ ] **`Set<T>`** built-in type

### Tooling
- [ ] **LSP: Go to definition**
- [ ] **LSP: Find references**
- [ ] **LSP: Rename symbol**
- [ ] **LSP: Signature help** (parameter hints)
- [ ] **LSP: Document symbols** (outline)
- [ ] **LSP: Code actions** (quick-fixes)
- [ ] **LSP: Incremental document sync** (TextDocumentSyncKind.Incremental)
- [ ] **VS Code: Snippets** (fn, class, for, match, yield, etc.)
- [ ] **VS Code: Task provider** (build, run, check tasks)
- [ ] **VS Code: Problem matcher** (C++ compile error parsing)
- [ ] **Formatter: Line-length wrapping**
- [ ] **Formatter: Import sorting**
- [ ] **CI: Run test suite on every push**

### Diagnostics
- [ ] **Unused variable/import warnings**
- [ ] **Dead code warnings** (beyond unreachable statements)
- [ ] **Missing return in non-void function** (all paths checked)
- [ ] **Match exhaustiveness checking**
- [ ] **Fix-it hints** (`help: remove argument`, `help: add semicolon`)
- [ ] **Error code documentation URLs**

---

## P2 — Nice to Have

- [ ] `from module import name` syntax
- [ ] `do`-`while` loop
- [ ] Labeled break/continue for nested loops
- [ ] `for (k, v) in map` destructuring
- [ ] Null-coalescing: `x ?? default`
- [ ] Spread operator: `[...list, new_item]`
- [ ] Pipe operator: `x |> f |> g`
- [ ] `HashMap` module documentation
- [ ] `LinkedList<T>`, `Queue<T>`, `Stack<T>`, `Heap<T>` collections
- [ ] Environment variable access: `getenv`, `setenv`
- [ ] Glob/path pattern matching
- [ ] `chdir`, `temp_dir`, `temp_file`
- [ ] Changelog
- [ ] Architecture/design document

---

## P3 — Post-v1.0

- [ ] Borrow checker / ownership system
- [ ] Async/await
- [ ] Package manager (`oxybelis install`, registry)
- [ ] Debugger (DAP adapter)
- [ ] WASM backend
- [ ] LLVM backend (direct compilation, no C++)
- [ ] Macro system
- [ ] `no_std` / embedded support
- [ ] FFI / C interop
- [ ] Documentation generator (`oxdoc`)

---

## Current Focus (v0.3.2 → v0.4.0)

1. [ ] **String stdlib** — add all string functions to both compilers
2. [ ] **SPEC.md** — write language specification
3. [ ] **Math module discussion** — Eigen vs MKL vs custom
4. [ ] **TUTORIAL.md** — getting started guide
