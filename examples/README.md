# Oxybelis Examples

Each file is self-contained with its own `fn main()`. Run any with:

```bash
python oxybelis.py examples/<name>.ox
```

| File | Features |
|---|---|
| `basics.ox` | Functions, recursion, factorial, fibonacci, primes, range-for, generics |
| `classes.ox` | Classes with methods, fields, struct-like usage (Vector2, Counter, Person) |
| `option.ox` | Null safety via `Option<T>`, safe_divide, find_index |
| `match.ox` | Pattern matching with ranges, HTTP status codes |
| `functional.ox` | map, filter, reduce, any, all, find, sum, min, max, for_each, chaining |
| `generators.ox` | `yield` keyword, `Generator<T>`, state-machine iteration |
| `itertools.ox` | combinations, permutations, chunked, windowed, pairwise, reversed, cycle, take_while, drop_while |
| `nim_like.ox` | Nim-style features: list of objects with str(), filter iteration |

For a combined showcase, run `python oxybelis.py example.ox`.
