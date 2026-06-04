// ────────────────────────────────────────────────────────────
//  examples/generators.ox  –  Lazy sequences with yield
// ────────────────────────────────────────────────────────────

fn count_to(n: int) -> Generator<int> {
    var i = 0;
    while i < n {
        yield i;
        i += 1;
    }
}

fn range_from(start: int, end: int) -> Generator<int> {
    var i = start;
    while i < end {
        yield i;
        i += 1;
    }
}

fn fib_gen(limit: int) -> Generator<int> {
    var a = 0;
    var b = 1;
    while a < limit {
        yield a;
        var next = a + b;
        a = b;
        b = next;
    }
}

fn even_numbers(limit: int) -> Generator<int> {
    var i = 0;
    while i < limit {
        if i % 2 == 0 {
            yield i;
        }
        i += 1;
    }
}

fn multiples_of(n: int, limit: int) -> Generator<int> {
    var i = n;
    while i < limit {
        yield i;
        i += n;
    }
}

fn main() {
    print("═══ Generator Demo ═══");
    print("");

    print("count_to(5):");
    for x in count_to(5) {
        print(x);
    }
    print("");

    print("range_from(3, 8):");
    for x in range_from(3, 8) {
        print(x);
    }
    print("");

    print("fib_gen(50):");
    for x in fib_gen(50) {
        print(x);
    }
    print("");

    print("even_numbers(20):");
    for x in even_numbers(20) {
        print(x);
    }
    print("");

    print("multiples_of(7, 50):");
    for x in multiples_of(7, 50) {
        print(x);
    }
    print("");

    print("═══ Done ═══");
}
