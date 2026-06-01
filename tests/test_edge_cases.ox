// ── test_edge_cases.ox ──
// Tests: edge cases and stress tests

// ── Deep recursion ──
fn deep(n: int) -> int {
    if n <= 0 { return 0 }
    return 1 + deep(n - 1)
}

// ── Fibonacci (tests recursion + performance) ──
fn fib(n: int) -> int {
    if n <= 1 { return n }
    return fib(n - 1) + fib(n - 2)
}

// ── Nested Option ──
fn wrap_twice(x: int) -> Option<Option<int>> {
    return Some(Some(x))
}

// ── Large list (stress test) ──
fn build_list(n: int) -> List<int> {
    var result: List<int> = []
    var i = 0
    while i < n {
        push(result, i)
        i = i + 1
    }
    return result
}

fn main() {
    // ── Deep recursion ──
    print(deep(100))
    print(deep(1000))
    
    // ── Fibonacci ──
    print(fib(10))
    print(fib(20))
    
    // ── Nested Option ──
    let nested = wrap_twice(42)
    // Unwrap outer Option to get inner Option
    let inner = nested.value
    // Unwrap inner Option to get value
    let val = inner.value
    print(val)
    
    // ── Large list ──
    let big = build_list(100)
    print(len(big))
    print(big[0])
    print(big[99])
    
    // ── Empty list ──
    var empty: List<int> = []
    print(len(empty))
    push(empty, 1)
    print(len(empty))
    
    // ── Empty string ──
    let es: str = ""
    print(len(es))
    
    // ── Negative numbers ──
    print(-5)
    print(abs(-10))
    print(-3 * -4)
    print(-3 + 5)
    
    // ── Float edge cases ──
    print(0.0)
    print(-1.5)
    print(floor(3.7))
    print(ceil(3.2))
    print(round(3.5))
    
    // ── Boolean logic ──
    print(true and true)
    print(true and false)
    print(false and true)
    print(false and false)
    print(true or true)
    print(true or false)
    print(false or true)
    print(false or false)
    
    // ── Chained comparison ──
    // Note: using && explicitly since chained comparisons not supported
    print((1 < 2) and (2 < 3))
    print((1 < 2) and (2 > 3))
    
    // ── Large numbers ──
    print(1000000)
    print(2147483647)
    
    // ── Multiple nested function calls ──
    print(fib(fib(6)))
}
