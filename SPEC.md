# Oxybelis Language Specification

**Version:** 0.3.4  
**Status:** Draft  

---

## 1. Introduction

Oxybelis is a statically-typed, Python-inspired language that transpiles to C++20. It is designed for:

- **Readability** — Python-like syntax with significant whitespace-free block structure (`{}`)
- **Performance** — transpiles to efficient C++ with no runtime overhead beyond the STL
- **Self-hosting** — the compiler (`compiler.ox`) is written in Oxybelis itself
- **Practicality** — built-in collections, functional chaining, pattern matching, generators, null safety

---

## 2. Lexical Structure

### 2.1 Comments

```oxybelis
// Single-line comment
/* Multi-line
   comment */
```

Comments are lexed but discarded. Nesting of `/* */` is not supported.

### 2.2 Identifiers

```
identifier ::= (letter | '_') { letter | digit | '_' }
letter      ::= 'a'..'z' | 'A'..'Z'
digit       ::= '0'..'9'
```

Identifiers are case-sensitive. Reserved keywords cannot be used as identifiers.

### 2.3 Keywords

```
and         as          bool        break       class
continue    elif        else        false       fn
for         Generator   if          import      int
let         List        Map         match       None
not         or          Option      pub         Result
return      Some        str         true        var
void        while       yield
```

### 2.4 Literals

**Integer literals:**
```
int_lit ::= digit { digit }
```
Range: 64-bit signed integer (`int64_t`).

**Float literals:**
```
float_lit ::= digit { digit } '.' digit { digit }
```
IEEE 754 double-precision (`double`).

**String literals:**
```
str_lit ::= '"' { char | escape } '"'
escape  ::= '\n' | '\t' | '\r' | '\\' | '\"' | '\0'
```

**Boolean literals:**
```
bool_lit ::= 'true' | 'false'
```

**None literal:**
```
none_lit ::= 'None'
```

### 2.5 Operators and Punctuation

```
+       -       *       /       %           // arithmetic
==      !=      <       >       <=      >=  // comparison
=       :       ,       ;       .           // punctuation
(       )       [       ]       {       }   // grouping
..                                          // range
...                                         // ellipsis (multidimensional slice)
?                                           // try-unwrap
```

### 2.6 Precedence and Associativity

| Precedence | Operator(s) | Associativity |
|-----------|-------------|--------------|
| 1 (highest) | `()` `[]` `.` `?` | left-to-right |
| 2 | unary `-` `not` `!` | right-to-left |
| 3 | `*` `/` `%` | left-to-right |
| 4 | `+` `-` | left-to-right |
| 5 | `..` | none |
| 6 | `<` `>` `<=` `>=` | left-to-right |
| 7 | `==` `!=` | left-to-right |
| 8 | `and` | left-to-right |
| 9 (lowest) | `or` | left-to-right |

---

## 3. Types

### 3.1 Primitive Types

| Type | Description | C++ Mapping |
|------|-------------|-------------|
| `int` | 64-bit signed integer | `int` |
| `float` | Double-precision IEEE 754 | `double` |
| `bool` | Boolean | `bool` |
| `str` | UTF-8 string | `std::string` |
| `void` | No value (return type only) | `void` |

### 3.2 Generic/Container Types

| Type | Description | C++ Mapping |
|------|-------------|-------------|
| `List<T>` | Dynamic array | `std::vector<T>` |
| `Map<K, V>` | Hash table | `std::unordered_map<K, V>` |
| `Option<T>` | Nullable value | `std::optional<T>` |
| `Result<T, E>` | Success-or-error | Custom struct |
| `Generator<T>` | Lazy sequence | State-machine class |

### 3.3 User-Defined Types

Classes defined with the `class` keyword introduce named types. See §7.

### 3.4 Type Inference

The `let` keyword introduces an immutable binding with type inferred from the initializer:

```oxybelis
let x = 42          // x: int
let name = "hello"  // name: str
let items = [1, 2, 3]  // items: List<int>
```

The `var` keyword introduces a mutable binding:

```oxybelis
var counter = 0      // counter: int, mutable
counter += 1
```

Explicit type annotations can be added:

```oxybelis
let x: int = 42
var items: List<str> = ["a", "b"]
```

### 3.5 Generic Parameters

Functions and classes can have type parameters in angle brackets:

```oxybelis
fn first<T>(items: List<T>) -> Option<T> { ... }
class Box<T> { value: T; }
```

---

### 3.6 Collection Types

Oxybelis provides a small set of built-in generic collection types and higher-level containers in the standard library.

| Type | Description | C++ Mapping |
|------|-------------|-------------|
| `Set<T>` | Unordered collection of unique elements | `std::unordered_set<T>` |
| `FrozenSet<T>` | Immutable set of unique elements | `std::unordered_set<T>` (immutable wrapper) |
| `Dict<K, V>` / `Map<K, V>` | Hash map (dictionary) | `std::unordered_map<K, V>` |
| `OrderedDict<K, V>` | Mapping that preserves insertion order | (preserved by language API; implementation detail may vary) |
| `Counter<T>` | Multiset / counting map | `Map<T, int>` |

These types are available either as language built-ins (core containers) or as modules in `oxlib/collections.ox`. They support the APIs described below.

Iteration semantics:
- `List<T>` iterates elements of type `T`.
- `Set<T>` iterates elements of type `T` (iteration order is unspecified).
- `Map<K,V>` / `Dict<K,V>` iteration yields keys of type `K` (use `.items()` to iterate key/value pairs, and `.values()` for values).

Note: `OrderedDict<K,V>` preserves insertion order when iterating `keys()`, `values()`, and `items()`.

Common operations (available as methods or helper functions):
- `len(c)` — number of elements (works for List, Set, Map, etc.).
- `contains(coll, x)` / `x in coll` — membership test (Set and Map keys).

- Set operations (for `a: Set<T>`, `b: Set<T>`):
  - `a.add(x)` / `set_add(a, x)` — insert element
  - `a.remove(x)` / `set_remove(a, x)` — remove element (error if missing) 
  - `a.discard(x)` — remove if present (no error)
  - `a.union(b)` / `a | b` — set union (returns `Set<T>`)
  - `a.intersection(b)` / `a & b` — set intersection
  - `a.difference(b)` / `a - b` — set difference
  - `a.symmetric_difference(b)` / `a ^ b` — symmetric difference
  - `a.issubset(b)` — true if `a` is subset of `b`
  - `a.issuperset(b)` — true if `a` is superset of `b`

- Map / Dict operations (for `m: Map<K,V>`):
  - `m[key]` — indexing (get value; behaviour on missing key depends on API; use `m.get(key, default)` or `map_get` builtin)
  - `m[key] = v` — set value (uses `map_set` builtin under the hood)
  - `m.keys()` — `List<K>` of keys (shallow copy)
  - `m.values()` — `List<V>` of values (shallow copy)
  - `m.items()` — `List<(K, V)>` of pairs
  - `m.pop(key)` — remove and return value
  - `m.update(other)` — insert/overwrite entries from `other`

- `Counter<T>` operations:
  - `Counter()` constructs an empty counter
  - `c.update(iterable)` — increment counts from `iterable`
  - `c.most_common(n)` — returns `List<(T, int)>` ordered by count descending
  - `c.elements()` — returns `List<T>` with elements repeated by their count

Immutability:
- `FrozenSet<T>` is an immutable set type. Methods that would mutate a `Set<T>` instead return a new `Set<T>` or `FrozenSet<T>` depending on the operation. `FrozenSet<T>` values are hashable and can be used as keys in maps if the element type is hashable.

Examples:

```oxybelis
let s: Set<int> = Set<int>()
s.add(1)
s.add(2)
print(len(s))           // 2

let a = Set<int>()
a.add(1)
a.add(2)
let b = Set<int>()
b.add(2)
b.add(3)
print(a.union(b))      // Set: {1,2,3}

let m: Dict<str,int> = Dict<str,int>()
m["x"] = 10
print(m.keys())        // ["x"]
for k in m { print(k) } // iterate keys
for (k,v) in m.items() { print(k + ": " + str(v)) }

let cnt = Counter<str>()
cnt.update(["a","b","a"])
print(cnt.most_common(1)) // [("a", 2)]
```

### 3.7 Collection APIs (Reference)

This section lists the commonly-available methods and helper functions for the standard collection types. Implementations are provided by the runtime/standard library (`oxlib/collections.ox`) and a subset are exposed as builtins for performance-sensitive operations.

Set<T>
- Construction: `Set<T>()` — returns an empty set
- Mutating methods:
  - `s.add(x)` / `set_add(s, x)` → void
  - `s.remove(x)` / `set_remove(s, x)` → void (throws if missing)
  - `s.discard(x)` → void (no error if missing)
  - `s.clear()` → void
- Non-mutating / queries:
  - `len(s)` → int
  - `s.contains(x)` / `contains(s, x)` → bool
  - `s.is_empty()` → bool
  - `s.union(t)` / `set_union(s,t)` → Set<T>
  - `s.intersection(t)` / `set_intersection(s,t)` → Set<T>
  - `s.difference(t)` / `set_difference(s,t)` → Set<T>
  - `s.symmetric_difference(t)` / `set_symdiff(s,t)` → Set<T>
  - `s.issubset(t)` / `set_is_subset(s,t)` → bool
  - `s.issuperset(t)` / `set_is_superset(s,t)` → bool
  - Operators supported: `|` (union), `&` (intersection), `-` (difference), `^` (symmetric difference)

Dict<K,V> / Map<K,V>
- Construction: `Dict<K,V>()` or `Map<K,V>()`
- Indexing and mutation:
  - `m[key]` — get (or insert default, depending on API); prefer `m.get(key, default)` when unsure
  - `m[key] = v` — set value (maps to `map_set` builtin)
  - `m.pop(key)` — remove and return value (throws if missing)
  - `map_get(m, key)`, `map_set(m, key, value)`, `map_contains(m, key)` — builtins
- Views and iteration:
  - `m.keys()` → List<K>
  - `m.values()` → List<V>
  - `m.items()` → List<(K, V)>
  - Iteration `for k in m { ... }` iterates keys (use `for (k,v) in m.items()` for pairs)

OrderedDict<K,V>
- Preserves insertion order for `keys()`, `values()`, `items()` and for iteration.
- API mirrors `Dict` but with predictable iteration order.

Counter<T>
- Conceptually `Map<T,int>` with convenience methods:
  - `Counter()` — construct
  - `c.update(iterable)` — increment counts for all elements in iterable
  - `c[elt]` — get count (0 if missing)
  - `c.most_common(n)` — return `List<(T, int)>` ordered by count desc
  - `c.elements()` — `List<T>` with elements repeated according to their counts

FrozenSet<T>
- Immutable set type. Construction via `frozenset(iterable)` or `FrozenSet<T>(existing_set)`.
- Hashable if element type `T` is hashable. Supports equality and use as map keys.

Concurrency & Mutability
- Collection types are not thread-safe by default. Concurrent mutation requires user synchronization.

Complexity Notes
- `Set<T>` operations (`add`, `remove`, `contains`, `len`) are expected O(1) average-case (backed by `std::unordered_set`).
- `Dict`/`Map` operations (`get`, `set`, `contains`) are expected O(1) average-case (backed by `std::unordered_map`).
- `OrderedDict` may fall back to `std::map` or a combined vector+hash storage depending on implementation; iteration/preservation of order is guaranteed, complexity depends on underlying representation.

Implementation details
- The compiler maps `List<T>` → `std::vector<T>`, `Map<K,V>` → `std::unordered_map<K,V>`, and `Set<T>` → `std::unordered_set<T>` in generated C++.
- For performance, some helper functions are provided as builtins (e.g. `map_get`, `map_set`, `set_add`) and are implemented in the runtime header so calls compile to idiomatic C++.

Examples (usage patterns):

```oxybelis
let s = Set<int>()
s.add(1)
if s.contains(1) {
    print("has 1")
}

let d = Dict<str,int>()
d["a"] = 1
for k in d.keys() { print(k) }
for (k,v) in d.items() { print(k + ": " + str(v)) }

let c = Counter<str>()
c.update(["x","y","x"]) // c["x"] == 2
```


## 4. Expressions

### 4.1 Literal Expressions

```
42           // int
3.14         // float
"hello"      // str
true         // bool
false        // bool
None         // Option<T> (empty)
```

### 4.2 Arithmetic Expressions

```oxybelis
x + y        // addition
x - y        // subtraction
x * y        // multiplication
x / y        // division
x % y        // modulo
-x           // negation
```

Types: `int` ⊕ `int` → `int`, `float` ⊕ `float` → `float`. Mixed `int`/`float` is promoted to `float`.

### 4.3 Comparison Expressions

```oxybelis
x == y       // equality
x != y       // inequality
x < y        // less than
x > y        // greater than
x <= y       // less or equal
x >= y       // greater or equal
```

Return type: `bool`.

### 4.4 Logical Expressions

```oxybelis
x and y      // logical AND (short-circuit)
x or y       // logical OR (short-circuit)
not x        // logical NOT
!x           // logical NOT (alternate)
```

Return type: `bool`. Short-circuit evaluation: `and` evaluates `y` only if `x` is true; `or` evaluates `y` only if `x` is false.

### 4.5 Range Expression

```oxybelis
start .. end   // RangeLit
```

Creates a range from `start` to `end` (exclusive). Used in `for` loops:

```oxybelis
for i in 0..10 { print(i) }   // prints 0 through 9
```

### 4.6 Call Expressions

```oxybelis
fn_name(arg1, arg2)           // function call
obj.method(arg1, arg2)         // method call
```

### 4.7 Index Expression

```oxybelis
list[0]        // index into List<T>
map["key"]     // index into Map<K, V>
```

### 4.8 Slice Expression

```oxybelis
list[1:3]        // slice from index 1 to 3 (exclusive)
list[1:]         // slice from index 1 to end
list[:3]         // slice from start to index 3
list[:]          // full slice (copy)
list[::2]        // every other element
list[1:5:2]      // slice from 1 to 5, step 2
```

Slicing creates a new `List<T>` with the selected elements. All slice components are optional:
- `[start:end]` — elements from `start` (inclusive) to `end` (exclusive)
- `[start:]` — from `start` to the end
- `[:end]` — from the start to `end`
- `[:]` — copy of the entire list
- `[::step]` — every `step`-th element
- `[start:end:step]` — combined

Negative indices are supported (Python-style), counting from the end of the list.

### 4.9 Struct/Class Initializer

```oxybelis
Vector2 { x: 3.0, y: 4.0 }
Person { name: "Alice", age: 30 }
```

Field order is not significant. All fields must be specified.

### 4.10 Option/Result Constructors

```oxybelis
Some(value)    // wrap a value in Option<T>
None           // empty Option<T>
Ok(value)      // successful Result<T, E>
Err(error)     // failed Result<T, E>
```

### 4.11 Try-Unwrap Operator

```oxybelis
expr?          // unwrap Option<T> or Result<T,E>
```

On `Option<T>`: returns `T` or aborts if `None`.  
On `Result<T, E>`: returns `T` or aborts if `Err`.

### 4.12 If-Else Expression (ternary)

Not yet implemented. Use `if`/`else` as statements.

### 4.13 Lambda Expressions

Not yet implemented. Use named function references for higher-order calls.

---

## 5. Statements

### 5.1 Variable Declaration

```oxybelis
let name = value          // immutable, inferred type
let name: Type = value    // immutable, explicit type
var name = value          // mutable, inferred type
var name: Type = value    // mutable, explicit type
```

`let` bindings cannot be reassigned. `var` bindings can be reassigned with `=`.

### 5.2 Assignment

```oxybelis
name = expr
name += expr
name -= expr
name *= expr
name /= expr
```

Compound assignments work with `int` and `float` types.

### 5.3 Block

```oxybelis
{
    statement1
    statement2
}
```

Introduces a new scope. Variables declared inside a block are not visible outside.

### 5.4 If / Elif / Else

```oxybelis
if cond1 {
    body1
} elif cond2 {
    body2
} else {
    body3
}
```

Conditions must be `bool`. The `elif` and `else` branches are optional. At most one branch executes.

### 5.5 While Loop

```oxybelis
while cond {
    body
}
```

Evaluates `cond` before each iteration. Zero iterations if `cond` is initially false.

### 5.6 For Loop

```oxybelis
for var in iterable {
    body
}
```

**Range iteration:**
```oxybelis
for i in 0..10 { ... }         // i = 0, 1, ..., 9
for i in start..end { ... }    // exclusive end
```

**List iteration:**
```oxybelis
for item in list { ... }
```

**Generator iteration:**
```oxybelis
for x in generator_fn() { ... }
```

### 5.7 Break / Continue

```oxybelis
break           // exit enclosing loop
continue        // skip to next iteration
```

Only valid inside `for` or `while` loops.

### 5.8 Return

```oxybelis
return          // void function
return expr     // non-void function
```

Returns from the enclosing function. The expression type must match the declared return type.

### 5.9 Yield

```oxybelis
yield expr      // emit a value from a generator
```

Only valid inside a function with return type `Generator<T>`. The function body is transpiled to a state machine — see §10.4.

### 5.10 Match

```oxybelis
match expr {
    pattern1 => result_expr1;
    pattern2 => result_expr2;
    _ => default_expr;
}
```

Patterns:

| Pattern | Matches |
|---------|---------|
| `literal` | Exact value (`0`, `true`, `"hello"`) |
| `start..end` | Range (inclusive start, exclusive end) |
| `_` | Wildcard (anything) |

Match arms are evaluated in order. The first matching arm executes and its result expression becomes the match result.

### 5.11 Expression Statement

```oxybelis
expr;
```

Any expression followed by a semicolon is evaluated for its side effects. Return value is discarded.

---

## 6. Functions

### 6.1 Function Definition

```oxybelis
fn name(param1: Type1, param2: Type2) -> ReturnType {
    body
}
```

- Parameters are always passed by value.
- The return type can be omitted for `void` functions.
- Generic type parameters:

```oxybelis
fn identity<T>(x: T) -> T {
    return x;
}
```

### 6.2 Generator Function

```oxybelis
fn count_to(n: int) -> Generator<int> {
    var i = 0;
    while i < n {
        yield i;
        i += 1;
    }
}
```

A function whose return type is `Generator<T>` and whose body contains at least one `yield` statement is transpiled to a state machine. See §10.4.

### 6.3 Function Calls

```oxybelis
let result = fn_name(arg1, arg2)
```

Arguments are evaluated left-to-right and passed by value.

### 6.4 Higher-Order Functions

Named functions can be passed as arguments:

```oxybelis
fn dbl(x: int) -> int { return x * 2; }
let doubled = list.map(dbl)
```

Lambda expressions are not yet supported — all higher-order usage requires named functions.

---

## 7. Classes

### 7.1 Class Definition

```oxybelis
class ClassName {
    field1: Type1;
    field2: Type2;

    fn method(self, arg: Type) -> ReturnType {
        body
    }
}
```

- Fields are public and accessed via `.` notation.
- Methods must take `self` as the first parameter.
- Methods are defined inline within the class body.
- No inheritance (single or multiple).
- No `static` methods.
- No constructors — use struct initializer syntax.

### 7.2 Instantiation

```oxybelis
let obj = ClassName { field1: val1, field2: val2 };
```

### 7.3 Method Calls

```oxybelis
obj.method(arg)
obj.field
```

### 7.4 Generic Classes

```oxybelis
class Box<T> {
    value: T;
}
```

### 7.5 Operator Overloading

Classes can define operator methods using the following naming convention:

| Operator | Method Name |
|----------|-------------|
| `+` | `op_add` |
| `-` | `op_sub` |
| `*` | `op_mul` |
| `/` | `op_div` |
| `%` | `op_mod` |
| `==` | `op_eq` |
| `!=` | `op_ne` |
| `<` | `op_lt` |
| `>` | `op_gt` |
| `<=` | `op_le` |
| `>=` | `op_ge` |
| unary `-` | `op_neg` |
| unary `!` | `op_not` |

These methods are defined like regular class methods with `self` as the first parameter:

```oxybelis
class Vec2 {
    x: float;
    y: float;

    fn op_add(self, other: Vec2) -> Vec2 {
        return Vec2 { x: self.x + other.x, y: self.y + other.y }
    }
    fn op_sub(self, other: Vec2) -> Vec2 {
        return Vec2 { x: self.x - other.x, y: self.y - other.y }
    }
    fn op_mul(self, scalar: float) -> Vec2 {
        return Vec2 { x: self.x * scalar, y: self.y * scalar }
    }
}

fn main() {
    let a = Vec2 { x: 1.0, y: 2.0 }
    let b = Vec2 { x: 3.0, y: 4.0 }
    let c = a + b   // calls a.op_add(b)
    let d = a - b   // calls a.op_sub(b)
    let e = a * 2.0 // calls a.op_mul(2.0)

    print(c.x)  // 4.0
    print(d.y)  // -2.0
    print(e.x)  // 2.0
}
```

Operator methods are resolved at compile-time based on the left operand's type. The type checker falls through to the default arithmetic/comparison rules if no matching operator method is found.

Comparison operators (`==`, `!=`, `<`, `>`, `<=`, `>=`) return `bool` by default but the overloaded method can return any type.

---

## 8. Modules and Imports

### 8.1 Import Statement

```oxybelis
import json
import path
import fs
import collections
```

Modules are `.ox` files searched in:
1. Source file's directory
2. Current working directory
3. `oxlib/` directory adjacent to the compiler

### 8.2 Module Structure

A module file defines functions and classes to be used by the importing file:

```oxybelis
// oxlib/json.ox
pub fn parse(input: str) -> Option<JsonValue> { ... }
```

Functions prefixed with `pub` are exported. Internal (non-`pub`) functions are module-private.

### 8.3 Import Resolution

Modules are compiled independently into C++ namespaces. Circular imports are detected and rejected.

---

## 9. Standard Library

### 9.1 Built-in Functions

Available without any import:

#### Type Conversion

| Function | Signature | Description |
|----------|-----------|-------------|
| `to_int(s)` | `str → int` | Parse string to integer |
| `to_float(s)` | `str → float` | Parse string to float |
| `str(v)` | `T → str` | Convert value to string |
| `to_upper(s)` | `str → str` | Uppercase string |
| `to_lower(s)` | `str → str` | Lowercase string |

#### String Operations

| Function | Signature | Description |
|----------|-----------|-------------|
| `len(s)` | `str → int` | String length |
| `str_get(s, i)` | `str × int → str` | Character at index (as single-char string) |
| `str_sub(s, start, end)` | `str × int × int → str` | Substring `[start, end)` |
| `str_contains(s, sub)` | `str × str → bool` | Substring containment |
| `str_split(s, delim)` | `str × str → List<str>` | Split by delimiter |
| `str_trim(s)` | `str → str` | Strip whitespace from both ends |
| `str_trim_start(s)` | `str → str` | Strip leading whitespace |
| `str_trim_end(s)` | `str → str` | Strip trailing whitespace |
| `str_replace(s, old, new)` | `str × str × str → str` | Replace first occurrence |
| `str_replace_all(s, old, new)` | `str × str × str → str` | Replace all occurrences |
| `str_join(v, delim)` | `List<str> × str → str` | Join strings with delimiter |
| `str_repeat(s, n)` | `str × int → str` | Repeat string n times |
| `str_reverse(s)` | `str → str` | Reverse string |
| `str_find(s, sub)` | `str × str → Option<int>` | Find substring index |
| `starts_with(s, prefix)` | `str × str → bool` | Prefix check |
| `ends_with(s, suffix)` | `str × str → bool` | Suffix check |
| `is_digit(c)` | `str → bool` | Single character is digit |
| `is_alpha(c)` | `str → bool` | Single character is alphabetic |
| `is_alnum(c)` | `str → bool` | Single character is alphanumeric |

#### Math

| Function | Signature | Description |
|----------|-----------|-------------|
| `sqrt(x)` | `float → float` | Square root |
| `abs(x)` | `float → float` | Absolute value |
| `pow(x, y)` | `float × float → float` | Power |
| `sin(x)` | `float → float` | Sine (radians) |
| `cos(x)` | `float → float` | Cosine (radians) |
| `tan(x)` | `float → float` | Tangent (radians) |
| `floor(x)` | `float → float` | Round down |
| `ceil(x)` | `float → float` | Round up |
| `round(x)` | `float → float` | Round to nearest |
| `log(x)` | `float → float` | Natural logarithm |
| `exp(x)` | `float → float` | Exponential |
| `max(a, b)` | `int × int → int` | Maximum |
| `min(a, b)` | `int × int → int` | Minimum |

#### Collections

| Function | Signature | Description |
|----------|-----------|-------------|
| `len(v)` | `List<T> → int` | List length |
| `push(v, x)` | `List<T> × T → void` | Append element |
| `pop(v)` | `List<T> → T` | Remove and return last |
| `contains(v, x)` | `List<T> × T → bool` | Linear search |
| `list_insert(v, i, x)` | `List<T> × int × T → void` | Insert at index |
| `list_remove(v, i)` | `List<T> × int → T` | Remove at index |

#### Map

| Function | Signature | Description |
|----------|-----------|-------------|
| `map_contains(m, k)` | `Map<K,V> × K → bool` | Key exists |
| `map_get(m, k)` | `Map<K,V> × K → V` | Get value (aborts if missing) |
| `map_set(m, k, v)` | `Map<K,V> × K × V → void` | Insert or update |

#### I/O

| Function | Signature | Description |
|----------|-----------|-------------|
| `print(v)` | `T → void` | Print value to stdout |
| `read_file(path)` | `str → str` | Read entire file |
| `read_lines(path)` | `str → List<str>` | Read file as lines |
| `write_file(path, contents)` | `str × str → void` | Write to file |
| `exec(cmd)` | `str → int` | Execute command |
| `exit(code)` | `int → void` | Exit process |
| `args()` | `→ List<str>` | Command-line arguments |

#### Filesystem

| Function | Signature | Description |
|----------|-----------|-------------|
| `fs_exists(path)` | `str → bool` | Path exists |
| `fs_is_file(path)` | `str → bool` | Is regular file |
| `fs_is_dir(path)` | `str → bool` | Is directory |
| `fs_mkdir(path)` | `str → void` | Create directory (recursive) |
| `fs_list_dir(path)` | `str → List<str>` | List directory contents |
| `fs_remove(path)` | `str → void` | Remove file or directory |
| `fs_rename(old, new)` | `str × str → void` | Rename/move |
| `fs_copy(from, to)` | `str × str → void` | Copy (recursive) |
| `fs_cwd()` | `→ str` | Current working directory |

### 9.2 List Methods

Available on any `List<T>` value via dot notation:

| Method | Signature | Description |
|--------|-----------|-------------|
| `.map(fn)` | `List<T> × (T → U) → List<U>` | Transform each element |
| `.filter(fn)` | `List<T> × (T → bool) → List<T>` | Keep matching elements |
| `.reduce(init, fn)` | `List<T> × U × (U × T → U) → U` | Left fold |
| `.for_each(fn)` | `List<T> × (T → void) → void` | Side-effect iteration |
| `.each(fn)` | Alias for `for_each` | |
| `.any(fn)` | `List<T> × (T → bool) → bool` | Any element matches |
| `.all(fn)` | `List<T> × (T → bool) → bool` | All elements match |
| `.find(fn)` | `List<T> × (T → bool) → Option<T>` | First match |
| `.sum()` | `List<T> → T` | Sum of elements |
| `.min()` | `List<T> → T` | Minimum element |
| `.max()` | `List<T> → T` | Maximum element |
| `.combinations(k)` | `List<T> × int → List<List<T>>` | All k-combinations |
| `.permutations(k)` | `List<T> × int → List<List<T>>` | All k-permutations |
| `.chunked(n)` | `List<T> × int → List<List<T>>` | Split into chunks of n |
| `.windowed(n)` | `List<T> × int → List<List<T>>` | All sliding windows of size n |
| `.pairwise()` | `List<T> → List<List<T>>` | Alias for windowed(2) |
| `.reversed()` | `List<T> → List<T>` | Reversed copy |
| `.cycle(n)` | `List<T> × int → List<T>` | Repeat n times |
| `.take_while(fn)` | `List<T> × (T → bool) → List<T>` | Take from start while true |
| `.drop_while(fn)` | `List<T> × (T → bool) → List<T>` | Skip from start while true |

### 9.3 Modules

| Module | File | Contents |
|--------|------|----------|
| `json` | `oxlib/json.ox` | Rudimentary JSON parsing (strings, numbers), `escape()` |
| `collections` | `oxlib/collections.ox` | `Deque<T>`, `DefaultDict<K,V>` |
| `path` | `oxlib/path.ox` | `path_join`, `path_split`, `path_dirname`, `path_basename`, `path_stem`, `path_ext`, `path_normalize` |
| `fs` | `oxlib/fs.ox` | File system operations (see built-in filesystem functions above) |

---

## 10. Code Generation / C++ Runtime

### 10.1 C++20 Target

Oxybelis transpiles to C++20. Each `.ox` file produces a `.cpp` file compiled with:

```bash
g++ -std=c++20 -O2 file.cpp -o file.exe
```

### 10.2 Type Mappings

| Oxybelis | C++ |
|----------|-----|
| `int` | `int` (typically 32-bit on most platforms, but the compiler uses `int` for simplicity) |
| `float` | `double` |
| `bool` | `bool` |
| `str` | `std::string` |
| `void` | `void` |
| `List<T>` | `std::vector<T>` |
| `Map<K,V>` | `std::unordered_map<K,V>` |
| `Option<T>` | `std::optional<T>` |
| `Result<T,E>` | Custom `struct Result<T,E> { bool is_ok; T value; E error; }` |
| `Generator<T>` | Custom class with `std::function<Option<T>()>` state machine |

### 10.3 Runtime Header

Every generated `.cpp` file includes a runtime header containing:
- Type aliases (`List`, `Map`, `Option`)
- Helper functions (`Some`, `None`, `Ok`, `Err`, `_ox_try`, `_ox_value`)
- `print()` overloads for all types
- `str()` conversion functions for all types
- Functional chaining functions (`_ox_map`, `_ox_filter`, etc.)
- Iterator toolkit functions (`_ox_combinations`, `_ox_chunked`, etc.)
- `Generator<T>` class
- Math functions via `using std::...`
- String helper functions
- System functions (`args`, `read_file`, `write_file`, `exec`, `exit`)
- Filesystem functions
- `main()` wrapper with UTF-8 console setup on Windows

### 10.4 Generator State Machine

When a function has return type `Generator<T>` and contains `yield`, the body is transpiled to a state-machine struct:

```cpp
struct _gen_State {
    int _state = 0;              // current state (0 = entry)
    // local variables promoted to struct members
    int i;                       // e.g. loop counter

    Option<T> _next() {
        switch (_state) {
            case 0: goto _entry;
            case 1: goto _resume_1;
            // ... more state labels
        }
        _entry:
        // ... original function body
        // each `yield expr;` becomes:
        //   { _state = N; return Some(expr); }
        //   case N: ;
        // after the switch:
        //   return None;  // done
    }
};
```

Each `yield` creates a numbered state. Control constructs (`while`, `for`, `if`) with yields inside use state transitions:

- **while**: loop check → case, body → case, exit → case
- **if/elif/else**: each branch has its own state
- **for over range**: state-machine for-loop with `int i`
- **for over list/generator**: iterator stored as struct member

The struct is wrapped in a lambda captured by `std::function<Option<T>()>`.

---

## 11. Memory Model

### 11.1 Value Semantics

All types use value semantics:
- Assignment copies the value
- Function arguments are passed by value
- Return values are returned by value

### 11.2 No Borrow Checker

Oxybelis does not have a borrow checker or ownership system. It relies on C++'s automatic storage and move semantics for performance. Users should be aware of potential copies of large `List<T>` values.

### 11.3 No Garbage Collector

Memory management is handled by C++ RAII:
- `std::vector<T>` owns its heap-allocated buffer
- `std::string` owns its heap-allocated buffer
- `std::optional<T>` uses inline storage for `T`
- No reference counting or garbage collection

---

## 12. Tooling

### 12.1 Compiler

```bash
oxybelis examples/basics.ox          # compile + run
oxybelis -S examples/basics.ox       # emit C++ to stdout
oxybelis -o out.cpp file.ox          # write C++ to file
oxybelis --cc clang++ file.ox        # use a different C++ compiler
oxybelis examples/basics.ox --check  # type-check only (Python version)
oxybelis examples/basics.ox --highlight  # syntax highlight & exit (Python version)
```

### 12.2 Python Reference Compiler

`oxybelis.py` includes:
- Full type checker (`--check`)
- Syntax highlighter (`--highlight`)
- Rich diagnostics with spans and notes

### 12.3 Self-Hosting Compiler

`compiler.ox` + `compiler.exe` is the bootstrapped compiler.
- ✅ Full type checker (`--check`)
- ✅ Rich diagnostics — `Span`/`Diagnostic` types, severity levels, error codes, source underlines
- ✅ `--check` flag for type-check-only mode
- ✅ Self-hosting: `compiler.exe compiler.ox -S` produces a correct `compiler2`.
- ❌ `--highlight` flag (not yet implemented in self-hosted version)

### 12.4 LSP Server

`ox-lsp` provides:
- Diagnostics on open/change/save
- Semantic token highlighting
- Hover type information
- Completions
- Document formatting

### 12.5 Formatter

```bash
python ox_fmt.py < file.ox      # format stdin to stdout
python ox_fmt.py file.ox        # format file in-place
```

`ox-lsp` also provides formatting via `textDocument/formatting`.

### 12.6 VS Code Extension

Provides syntax highlighting, LSP integration, and commands for transpile/build/check/format.

---

## 13. Grammar (EBNF)

```
program         = { import_stmt | fn_def | class_def }

import_stmt     = 'import' identifier { '.' identifier } ';'

fn_def          = 'fn' [type_param] identifier '(' [param_list] ')' ['->' type] block
type_param      = '<' identifier '>'
param_list      = param { ',' param }
param           = identifier ':' type

class_def       = 'class' identifier [type_param] '{' { field | method } '}'
field           = identifier ':' type ';'
method          = fn_def    // (must have 'self' as first parameter)

block           = '{' { stmt } '}'

stmt            = let_decl | var_decl | assignment
                | if_stmt | while_stmt | for_stmt | match_stmt
                | return_stmt | yield_stmt | break_stmt | continue_stmt
                | expr_stmt | block

let_decl        = 'let' identifier [':' type] '=' expr ';'
var_decl        = 'var' identifier [':' type] '=' expr ';'
assignment      = expr ('=' | '+=' | '-=' | '*=' | '/=') expr ';'

if_stmt         = 'if' expr block { 'elif' expr block } [ 'else' block ]
while_stmt      = 'while' expr block
for_stmt        = 'for' identifier 'in' expr block

match_stmt      = 'match' expr '{' { pattern '=>' expr ';' } '}'
pattern         = literal | expr '..' expr | '_'

return_stmt     = 'return' [expr] ';'
yield_stmt      = 'yield' expr ';'
break_stmt      = 'break' ';'
continue_stmt   = 'continue' ';'
expr_stmt       = expr ';'

expr            = or_expr
or_expr         = and_expr { 'or' and_expr }
and_expr        = cmp_expr { 'and' cmp_expr }
cmp_expr        = add_expr { ('==' | '!=' | '<' | '>' | '<=' | '>=') add_expr }
add_expr        = mul_expr { ('+' | '-') mul_expr }
mul_expr        = unary_expr { ('*' | '/' | '%') unary_expr }
unary_expr      = ('-' | 'not' | '!') unary_expr | postfix_expr
postfix_expr    = primary_expr { '(' [expr_list] ')' | '[' slice_or_index ']' | '.' identifier | '?' }
slice_or_index  = expr [':' [expr] [':' [expr]]] { ',' expr [':' [expr] [':' [expr]]] }
                | '...' { ',' expr [':' [expr] [':' [expr]]] }
primary_expr    = literal | identifier | '(' expr ')' | range_expr
                | 'Some' '(' expr ')' | 'Ok' '(' expr ')' | 'Err' '(' expr ')'
                | type_name '{' field_init_list '}'
range_expr      = expr '..' expr

literal         = int_lit | float_lit | str_lit | 'true' | 'false' | 'None'
type            = 'int' | 'float' | 'bool' | 'str' | 'void'
                | 'List' '<' type '>'
                | 'Map' '<' type ',' type '>'
                | 'Option' '<' type '>'
                | 'Result' '<' type ',' type '>'
                | 'Generator' '<' type '>'
                | identifier [type_args]
field_init_list = identifier ':' expr { ',' identifier ':' expr }
expr_list       = expr { ',' expr }
type_args       = '<' type { ',' type } '>'
identifier      = (letter | '_') { letter | digit | '_' }
```

---

## 14. Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.3.4 | 2026-06-06 | Operator overloading, Python-style slicing `[start:end:step]`, NdArray slice support, ellipsis `...` for multidimensional indexing |
| 0.3.3 | 2026-06-05 | LSP markdown docs, function token highlighting, formatter blank-line preservation, cleanup |
| 0.3.2 | 2026-06-04 | Generators, yield, itertools, examples, string stdlib, self-hosting compiler |
| 0.3.0 | — | Collections, functional chaining, pattern matching |
| 0.2.0 | — | LSP server, VS Code extension, formatter |
| 0.1.0 | — | Initial release: basic types, functions, classes, modules |
