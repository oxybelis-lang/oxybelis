// ── Generator tests ──────────────────────────────────────────

// Basic generator: count_to
fn count_to(n: int) -> Generator<int> {
    var i = 0
    while i < n {
        yield i
        i += 1
    }
}

// Generator with range-like behavior
fn range_from(start: int, end: int) -> Generator<int> {
    var i = start
    while i < end {
        yield i
        i += 1
    }
}

// Generator with if condition inside
fn even_up_to(n: int) -> Generator<int> {
    var i = 0
    while i < n {
        if i % 2 == 0 {
            yield i
        }
        i += 1
    }
}

fn main() {
    print("=== count_to(5) ===")
    for x in count_to(5) {
        print(x)
    }

    print("=== range_from(2, 6) ===")
    for x in range_from(2, 6) {
        print(x)
    }

    print("=== even_up_to(10) ===")
    for x in even_up_to(10) {
        print(x)
    }
}
