Generator: Literal Emission & Runtime Helpers
===========================================

Why
---
Historically the C++ code generator emitted raw C-style string literals ("foo") and
untyped braced initializers ({1,2,3}) for list literals. Those sometimes lead to
template-deduction and STL instantiation issues (e.g. const char* vs std::string, or
std::vector<void> when a literal had no inferred element type). These problems
manifested as g++ errors on some toolchains and made emitted C++ fragile.

What changed
------------
- String literals now emit std::string("...") so they have a concrete std::string
  type in generated C++ and won't conflict with templated functions expecting
  std::string.
- List literals emit a typed initializer when the typechecker can infer the
  element type: e.g. List<int> literals become std::vector<int>{1,2,3} instead of
  {1,2,3}. This avoids creating std::vector<void> or ambiguous overload resolution.
- gen_var_decl sets a ListLit._type when a variable has an explicit List<T>
  annotation; this ensures local declarations like `let v: List<int> = [..]` produce
  correctly-typed temporaries.
- Added and synced small set helpers (set_add, set_contains, etc.) to both
  oxybelis.py (emitted runtime) and compiler.ox so generated code and the
  compiler runtime expose the same API.

Rationale / tradeoffs
---------------------
- Emitting typed temporaries moves type-correctness into the generator rather than
  relying on permissive runtime overloads. This avoids masking type issues and
  produces clearer C++ code.
- We avoided introducing permissive overloads (e.g. accepting const char*) which
  would hide mismatches and make behavior less explicit.

Developer notes
---------------
- If you add new helper functions or change signatures in the emitted runtime,
  update both oxybelis.py and compiler.ox to keep the hand-maintained runtime and
  the emitted header in sync.
- New tests were added under tests/:
  - test_literal_emission.ox
  - test_literal_generics.ox
  These validate string/list literal emission with generics and nested lists.

How to run tests
----------------
From the repository root:

  python tests/run_tests.py

This runs the compiler to C++ for each test, compiles the C++, and executes the
binary. All tests should pass after the changes described here.
