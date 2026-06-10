# Oxybelis v1.0 Roadmap

## P0 — Blocking

### Self-hosting compiler parity (compiler.ox)
- [x] **Type checker** — fully mirrored in `compiler.ox`
  - Type inference for all expressions — `infer_type_impl` covers literals, idents, binops, unary, calls, method calls, index, attr, struct literals, ranges, `Some`/`Ok`/`Err`
  - Function signature validation — param count/type checking, return type checking
  - Generic type parameter resolution — `generic_params` scope with `is_generic`
  - Method dispatch — class method lookup via `cls_field_names`/`cls_field_types`
  - ⚠️ Known limitations: no overloaded function resolution for user-defined functions; no inference for `map` callback return types beyond `List<elem_type>`
- [x] **Rich diagnostics** — fully implemented
  - `Span`/`Diagnostic` types with line/col
  - Multi-line error underlines via `render_one`
  - Severity levels
  - Error codes (`E0002`, `E0308`, `E0057`, `E0060`, `E0425`, etc.)
  - `--check` flag for type-check-only mode
  - ❌ `--highlight` flag (not yet in self-hosted version)
- [x] **Span tracking in AST** — `s_line`/`s_col` fields in every node

### Standard library — Strings
- [x] All string functions implemented in `oxybelis.py` RUNTIME C++:
  - `str_split`, `str_trim`/`str_trim_start`/`str_trim_end`, `str_replace`/`str_replace_all`
  - `str_join`, `to_upper`/`to_lower`, `starts_with`/`ends_with`
  - `str_repeat`, `str_reverse`, `str_find`
- [ ] Mirror all same functions in `compiler.ox` runtime C++ emit
- [ ] `str_format(fmt, args...)` → `str` (sprintf-style)

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
- [x] `input()` / `read_line()` → `str`
- [ ] `eprint(msg)` / `eprintln(msg)` → stderr output
- [ ] `append_file(path, content)` → file append mode
- [x] `read_file_lines(path)` → `List<str>` (already exists as `read_lines`)
- [ ] `temp_dir()` / `temp_file()` → path utilities

### Standard library — DateTime
- [ ] `now()` → timestamp / DateTime struct
- [ ] `format_datetime(fmt)` → `str`
- [ ] `parse_datetime(s, fmt)` → `Option<DateTime>`
- [ ] Time duration / arithmetic

### Documentation
- [x] **SPEC.md** — language specification up to date
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
- [x] **Lambda expressions** — `|x, y| x + y`
- [x] **Ternary expressions** — `x if cond else y`
- [x] **Tuple types** — `(int, str)` return types, destructuring, type annotations
- [x] **Default parameter values** — `fn foo(a: int, b: int = 10)`
- [x] **`in` operator** — `x in list` → `bool`
- [x] **Variadic `print`** — `print(a, b, c)` space-separated
- [ ] **Enums / sum types** — `enum Option<T> { None, Some(T) }` with match destructuring
- [ ] **List comprehensions** — `[x * 2 for x in list if x > 0]`
- [ ] **`Set<T>`** built-in type

### Tooling
- [ ] **LSP: Go to definition**
- [ ] **LSP: Find references**
- [ ] **LSP: Rename symbol**
- [ ] **LSP: Signature help for user-defined functions**
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

## Current Focus (v0.4.0 → v0.5.0)

1. [x] **Tuples** — destructuring, type annotations, `sorted` on tuples
2. [x] **Lambdas** — `|params| expr` syntax with auto type deduction
3. [x] **Ternary** — `x if cond else y` with backtrack parsing
4. [x] **`in` operator** — `x in list` generates `contains(list, x)`
5. [x] **Default parameter values** — `fn f(a: int = 5)`
6. [x] **Variadic `print`** — `print(a, b, c)` space-separated
7. [x] **LSP recursive symbol completion** — suggests vars inside fn bodies
8. [x] **Bootstrap hardening** — verify generator state-machine codegen works in self-hosted output; test self-hosted compile of `oxlib/` modules; fight-test with real-world `.ox` files
    - [x] Fix `declare_var`/`pop_scope` empty-scope crash in `compiler.ox` and `oxybelis.py`
    - [x] Clean stale build artifacts and log files
9. [ ] **LSP features** — go-to-definition, find references, rename
10. [ ] **Math module discussion** — Eigen vs MKL vs custom
