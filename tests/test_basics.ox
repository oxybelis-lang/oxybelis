// ── test_basics.ox ──
// Tests: types, operators, variables, control flow, functions

fn fib(n: int) -> int {
    if n <= 1 { return n }
    return fib(n - 1) + fib(n - 2)
}

fn factorial(n: int) -> int {
    var result = 1
    var i = 1
    while i <= n {
        result = result * i
        i = i + 1
    }
    return result
}

fn sum_range(n: int) -> int {
    var s = 0
    for i in range(0, n) {
        s = s + i
    }
    return s
}

fn is_even(x: int) -> bool {
    return x % 2 == 0
}

fn main() {
    // ── int arithmetic ──
    print(fib(10))
    print(factorial(5))
    print(sum_range(10))
    
    // ── float ──
    let a: float = 3.5
    let b: float = 2.0
    print(a + b)
    print(a * b)
    print(a - b)
    print(a / b)
    
    // ── bool ──
    print(true and false)
    print(true or false)
    print(not true)
    print(is_even(42))
    
    // ── comparison ──
    print(1 < 2)
    print(1 > 2)
    print(1 <= 1)
    print(2 >= 2)
    print(1 == 1)
    print(1 != 2)
    
    // ── str ──
    let s: str = "hello"
    print(s)
    print(s + " world")
    
    // ── if/elif/else ──
    let x = 0
    if x > 0 {
        print("pos")
    } elif x < 0 {
        print("neg")
    } else {
        print("zero")
    }
    
    // ── for over range ──
    var count = 0
    for i in range(0, 5) {
        count = count + 1
    }
    print(count)
    
    // ── while ──
    var n = 3
    var acc = 1
    while n > 0 {
        acc = acc * n
        n = n - 1
    }
    print(acc)
    
    // ── break/continue ──
    var sum = 0
    var i = 0
    while i < 10 {
        i = i + 1
        if i % 2 == 0 { continue }
        if i > 7 { break }
        sum = sum + i
    }
    print(sum)
    
    // ── compound assignment ──
    
    // ── math builtins ──
    print(sqrt(9.0))
    print(abs(-5))
    print(pow(2.0, 3.0))
    print(max(10, 20))
    print(min(10, 20))
    
    // ── compound assignment ──
    var ca = 10
    ca += 5
    print(ca)
    ca -= 3
    print(ca)
    ca *= 2
    print(ca)
    ca /= 3
    print(ca)
    
    // ── void function ──
    print("done")
}
