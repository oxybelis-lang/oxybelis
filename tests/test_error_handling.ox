// ── test_error_handling.ox ──
// Tests: assert, defer, try/catch

fn try_divide(a: int, b: int) -> Result<int, str> {
    if b == 0 { return Err("division by zero") }
    return Ok(a / b)
}

fn maybe_value(should_be_some: bool) -> Option<int> {
    if should_be_some { return Some(42) }
    return None
}

fn main() {
    // ── assert ──
    assert(true)
    assert(1 == 1, "one equals one")
    print("assert_ok")

    // ── defer ──
    print("before_defer")
    defer print("deferred")
    print("after_defer")

    // ── try/catch with Result ──
    try {
        let val = try_divide(10, 2)?
        print("div_ok_" + str(val))
    } catch e {
        print("should_not_reach_" + e)
    }

    try {
        let val = try_divide(1, 0)?
        print("should_not_reach_" + str(val))
    } catch e {
        print("caught_" + e)
    }

    // ── try/catch with Option ──
    try {
        let val = maybe_value(true)?
        print("opt_ok_" + str(val))
    } catch e {
        print("should_not_reach_" + e)
    }

    try {
        let val = maybe_value(false)?
        print("should_not_reach_" + str(val))
    } catch e {
        print("caught_opt_" + e)
    }

    print("done")
}
