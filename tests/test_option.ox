// ── test_option.ox ──
// Tests: Option, Some, None, .value, ?

fn try_get(idx: int, max: int) -> Option<int> {
    if idx < max { return Some(idx * 10) }
    return None
}

fn main() {
    // ── Some/None basics ──
    let a = Some(42)
    print(a)
    
    let b: Option<int> = None
    print(b)
    
    // ── .value unwrap ──
    let c = Some(99)
    print(c.value)
    
    // ── None compatibility ──
    let d: Option<int> = None
    print(d)
    
    // ── Option returned from function ──
    let e = try_get(2, 5)
    print(e)
    
    let f = try_get(10, 5)
    print(f)
    
    // ── .value on Option from function ──
    print(try_get(1, 5).value)
    
    // ── ? operator on Some ──
    let g = Some(77)
    let unwrapped = g?
    print(unwrapped)
    
    // ── ? operator on Option from function ──
    print(try_get(3, 5)?)
    
    // ── Option<str> ──
    let h = Some("hello")
    print(h)
    print(h.value)
    
    // ── Option<float> ──
    let i = Some(3.14)
    print(i)
    print(i.value)
}
