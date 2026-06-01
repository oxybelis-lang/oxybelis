// ── test_result.ox ──
// Tests: Result, Ok, Err, ?

fn safe_div(a: int, b: int) -> Result<int, str> {
    if b == 0 { return Err(str("division by zero")) }
    return Ok(a / b)
}

fn parse_int(s: str) -> Result<int, str> {
    if len(s) == 0 { return Err(str("empty string")) }
    if not is_digit(str_get(s, 0)) and s != "-0" {
        return Err(str("not a number"))
    }
    return Ok(to_int(s))
}

fn main() {
    // ── Ok Result ──
    let r1 = safe_div(10, 2)
    print(r1)
    
    // ── Err Result ──
    let r2 = safe_div(10, 0)
    print(r2)
    
    // ── ? operator ──
    let val = r1?
    print(val)
    
    // ── Parse with Result ──
    let p1 = parse_int("42")
    print(p1)
    
    let p2 = parse_int("abc")
    print(p2)
    
    let p3 = parse_int("")
    print(p3)
    
    // ── ? on Result from function ──
    let parsed = parse_int("99")?
    print(parsed)
}
