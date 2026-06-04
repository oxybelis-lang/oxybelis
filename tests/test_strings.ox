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
    
    // ── str_split ──
    print(str_split("a,b,c", ","))
    
    // ── str_trim ──
    print("'" + str_trim("  hello  ") + "'")
    print("'" + str_trim_start("  hello  ") + "'")
    print("'" + str_trim_end("  hello  ") + "'")
    
    // ── str_replace / str_replace_all ──
    print(str_replace("hello world", "world", "there"))
    print(str_replace_all("a-b-c", "-", "/"))
    
    // ── str_join ──
    print(str_join(["a", "b", "c"], ","))
    print(str_join(["x"], "---"))
    
    // ── to_upper / to_lower ──
    print(to_upper("Hello World"))
    print(to_lower("Hello World"))
    
    // ── starts_with / ends_with ──
    print(starts_with("hello", "he"))
    print(starts_with("hello", "xyz"))
    print(ends_with("hello", "lo"))
    print(ends_with("hello", "la"))
    
    // ── str_repeat ──
    print(str_repeat("ha", 3))
    
    // ── str_reverse ──
    print(str_reverse("hello"))
    
    // ── str_find ──
    print(str_find("hello world", "world"))
    print(str_find("hello world", "xyz"))
    
    // ── str puts (for output matching) ──
    print("end")
}
