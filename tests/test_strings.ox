// ── test_strings.ox ──
// Tests: string operations

fn main() {
    let s = "Hello, Oxybelis!"
    
    // ── len ──
    print(len(s))
    
    // ── str_get ──
    print(str_get(s, 1))
    print(str_get(s, 0))
    
    // ── str_sub ──
    print(str_sub(s, 0, 5))
    print(str_sub(s, 7, 10))
    print(str_sub(s, 3, 3))
    
    // ── string comparison ──
    print("abc" == "abc")
    print("abc" == "xyz")
    print("abc" != "xyz")
    
    // ── string concat (use :str to avoid const char*) ──
    let a: str = "foo"
    let b: str = "bar"
    print(a + b)
    
    // ── is_digit / is_alpha / is_alnum ──
    print(is_digit("5"))
    print(is_digit("a"))
    print(is_alpha("x"))
    print(is_alpha("9"))
    print(is_alnum("Z"))
    print(is_alnum("_"))
    
    // ── to_int / to_float ──
    print(to_int("42"))
    print(to_float("3.14"))
    
    // ── str() conversion ──
    print(str(42))
    print(str(3.14))
    print(str(true))
    print(str(false))
    
    // ── str puts (for output matching) ──
    print("end")
}
