# Oxybelis Examples

Each file is self-contained with its own `fn main()`. Compile and run any with:

```bash
compiler.exe examples/<name>.ox -o examples/<name>.cpp
g++ -std=c++17 examples/<name>.cpp -o examples/<name>.exe -I NumCpp\include
examples\<name>.exe
```

To type-check only (no code generation):

```bash
python oxybelis.py examples/<name>.ox --check
```

## Index

| File | Features |
|---|---|
| `basics.ox` | Functions, recursion (factorial, fibonacci), primes, `Option<T>`, `List<T>`, range-for |
| `classes.ox` | Classes with methods and fields (Vector2, Counter, Person) |
| `option.ox` | Null safety via `Option<T>`: safe_divide, find_index |
| `match.ox` | Pattern matching with ranges and literals, HTTP status codes |
| `functional.ox` | map, filter, reduce, any, all, find, sum, min, max, for_each, chaining |
| `generators.ox` | `yield` keyword, `Generator<T>`, state-machine iteration |
| `itertools.ox` | combinations, permutations, chunked, windowed, pairwise, cycle, take_while |
| `strings.ox` | String manipulation: split, trim, replace, join, case conversion, reverse, find |
| `math_demo.ox` | Math module: sqrt, sin, cos, linspace, dot product, NumCpp matrices |
| `nim_like.ox` | Nim-style list comprehension iteration over objects with `str()` |
| `user.ox` | Kitchen sink: generics, classes, `Result<T, E>`, heapq, numpy, time, mutation |
