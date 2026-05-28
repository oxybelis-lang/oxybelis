// ────────────────────────────────────────────────────────────
//  example.ox  –  Oxybelis language showcase
// ────────────────────────────────────────────────────────────

// ── Basic functions ──────────────────────────────────────────
fn greet(name: str) -> str {
    return "Hello, " + name + "!";
}

fn factorial(n: int) -> insst 
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

// ── Generic functions ─────────────────────────────────────────
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

// ── Classes ───────────────────────────────────────────────────
class Vector2 {
    x: float;
    y: float;

    fn length(self) -> float {
        return sqrt(self.x * self.x + self.y * self.y);
    }

    fn add(self, other: Vector2) -> Vector2 {
        return Vector2 { x: self.x + other.x, y: self.y + other.y };
    }

    fn scale(self, factor: float) -> Vector2 {
        return Vector2 { x: self.x * factor, y: self.y * factor };
    }

    fn dot(self, other: Vector2) -> float {
        return self.x * other.x + self.y * other.y;
    }
}

class Counter {
    value: int;

    fn increment(self) {
        self.value += 1;
    }

    fn decrement(self) {
        self.value -= 1;
    }

    fn reset(self) {
        self.value = 0;
    }

    fn get(self) -> int {
        return self.value;
    }
}

// ── Option type (null-safety) ─────────────────────────────────
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

// ── Match expressions ─────────────────────────────────────────
fn classify(n: int) -> str {
    match n {
        0 => return "zero";
        1..10 => return "small   (1-9)";
        10..100 => return "medium  (10-99)";
        _ => return "large   (100+)";
    }
    return "";
}

fn http_status(code: int) -> str {
    match code {
        200 => return "OK";
        201 => return "Created";
        400 => return "Bad Request";
        401 => return "Unauthorized";
        403 => return "Forbidden";
        404 => return "Not Found";
        500 => return "Internal Server Error";
        _ => return "Unknown";
    }
    return "";
}

// ── Main ──────────────────────────────────────────────────────
fn main() {
    print("═══ Oxybelis Language Demo ═══");
    print("");

    // Basic calls
    print(greet("World"));
    print(greet("Oxybelis"));
    print("");

    // Arithmetic & recursion
    print("factorial(10) =");
    print(factorial(10));
    print("fibonacci(10) =");
    print(fibonacci(10));
    print("");

    // Range for-loop
    print("Primes under 30:");
    for i in 2..30 {
        if is_prime(i) {
            print(i);
        }
    }
    print("");

    // Lists & generics
    var nums: List<int> = [10, 3, 7, 1, 42, 5, 99];
    print("Sum:");
    print(sum_ints(nums));
    print("");

    // Option type
    let r1 = safe_divide(10.0, 4.0);
    let r2 = safe_divide(1.0, 0.0);
    print("10 / 4 =");
    print(r1);
    print("1 / 0 =");
    print(r2);
    print("");

    // Struct usage
    let v1 = Vector2 { x: 3.0, y: 4.0 };
    let v2 = Vector2 { x: 1.0, y: 2.0 };
    print("v1 length:");
    print(v1.length());
    let v3 = v1.add(v2);
    print("v1 + v2 =");
    print(v3.x);
    print(v3.y);
    print("");

    // Match
    print("classify(0)   =");
    print(classify(0));
    print("classify(7)   =");
    print(classify(7));
    print("classify(55)  =");
    print(classify(55));
    print("classify(200) =");
    print(classify(200));
    print("");

    // HTTP status match
    print("HTTP 404 =");
    print(http_status(404));
    print("HTTP 200 =");
    print(http_status(200));
    print("");

    // While loop
    var c: Counter = Counter { value: 0 };
    c.increment();
    c.increment();
    c.increment();
    c.decrement();
    print("Counter after +3 -1:");
    print(c.get());
    print("");
    print("═══ Done ═══");
}
