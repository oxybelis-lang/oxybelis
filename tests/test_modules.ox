// ── test_modules.ox ──
// Tests: import functionality

import json

fn main() {
    // ── json.parse_str ──
    let r1 = json.parse_str("\"hello world\"")
    print(r1)
    
    // ── json.parse_float ──
    let r2 = json.parse_float("3.14159")
    print(r2)
    
    // ── json.parse ──
    let r3 = json.parse("true")
    print(r3)
    
    let r4 = json.parse("null")
    print(r4)
    
    // ── json.escape ──
    let escaped = json.escape("hello\"world")
    print(escaped)
}
