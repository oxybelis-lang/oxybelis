// ────────────────────────────────────────────────────────────
//  examples/option.ox  –  Option/Optional type (null safety)
// ────────────────────────────────────────────────────────────

fn safe_divide(a: float, b: float) -> Option<float> {
    if b == 0.0 {
        return None;
    }
    return Some(a / b);
}

fn find_index(items: List<int>, target: int) -> Option<int> {
    var i: int = 0;
    for item in items {
        if item == target {
            return Some(i);
        }
        i += 1;
    }
    return None;
}

fn main() {
    print("═══ Option Demo ═══");
    print("");

    let r1 = safe_divide(10.0, 4.0);
    let r2 = safe_divide(1.0, 0.0);
    print("10 / 4 =");
    print(r1);
    print("1 / 0 =");
    print(r2);
    print("");

    let nums: List<int> = [10, 3, 7, 1, 42, 5, 99];
    print("find_index(nums, 42) =");
    print(find_index(nums, 42));
    print("find_index(nums, 999) =");
    print(find_index(nums, 999));
    print("");

    // Manual handling via Option-to-Option chaining
    let val = safe_divide(100.0, 3.0);
    print("100 / 3 =");
    print(val);

    print("═══ Done ═══");
}
