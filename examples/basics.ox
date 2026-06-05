// ────────────────────────────────────────────────────────────
//  examples/basics.ox  –  Functions, recursion, loops, primes
// ────────────────────────────────────────────────────────────
fn greet(name: str) -> str {
    return "Hello, " + name + "!";
}

fn factorial(n: int) -> int {
    if n <= 1 {
        return 1;
    }
    return n * factorial(n - 1);
}

fn fibonacci(n: int) -> int {
    if n <= 1 {
        return n;
    }
    return fibonacci(n - 1) + fibonacci(n - 2);
}

fn is_prime(n: int) -> bool {
    if n < 2 {
        return false;
    }
    var i: int = 2;
    while i * i <= n {
        if n % i == 0 {
            return false;
        }
        i += 1;
    }
    return true;
}

fn first<T>(items: List<T>) -> Option<T> {
    if len(items) == 0 {
        return None;
    }
    return Some(items[0]);
}

fn sum_ints(items: List<int>) -> int {
    var total: int = 0;
    for x in items {
        total += x;
    }
    return total;
}

fn main() {
    print("═══ Basics Demo ═══");
    print("");

    print(greet("World"));
    print(greet("Oxybelis"));
    print("");

    print("factorial(10) =");
    print(factorial(10));
    print("fibonacci(10) =");
    print(fibonacci(10));
    print("");

    print("Primes under 30:");
    for i in 2..30 {
        if is_prime(i) {
            print(i);
        }
    }
    print("");

    var nums: List<int> = [10, 3, 7, 1, 42, 5, 99];
    print("first(nums) =");
    print(first(nums));
    print("sum_ints(nums) =");
    print(sum_ints(nums));
    print("");

    print("═══ Done ═══");
}
