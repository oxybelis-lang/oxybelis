// ────────────────────────────────────────────────────────────
//  example.ox  –  Oxybelis language showcase
// ────────────────────────────────────────────────────────────

// ── Basic functions ──────────────────────────────────────────
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

// ── Struct-like class (Nim's "object") ──────────────────────────
class Person {
    name: str;
    age: int;
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

// ── Functional chaining helpers ────────────────────────────────
fn dbl(x: int) -> int {
    return x * 2;
}

fn is_even(x: int) -> bool {
    return x % 2 == 0;
}

fn is_odd(x: int) -> bool {
    return x % 2 == 1;
}

fn add(a: int, b: int) -> int {
    return a + b;
}

fn print_item(x: int) {
    print(x);
}

fn lt4(x: int) -> bool {
    return x < 4;
}

// ── Generators (lazy sequences with yield) ───────────────────────
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

    // ── Generators ─────────────────────────────────────────
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

    // ── Functional chaining ─────────────────────────────────
    print("═══ Functional Chaining Demo ═══");
    print("");
    var numbers: List<int> = [1, 2, 3, 4, 5, 6];
    print("numbers.map(dbl):");
    let dbld = numbers.map(dbl);
    print(dbld);
    print("numbers.filter(is_even):");
    let evens = numbers.filter(is_even);
    print(evens);
    print("numbers.reduce(0, add):");
    let sum = numbers.reduce(0, add);
    print(sum);
    print("numbers.any(is_even):");
    print(numbers.any(is_even));
    print("numbers.all(is_even):");
    print(numbers.all(is_even));
    print("numbers.find(is_even):");
    print(numbers.find(is_even));
    print("numbers.sum():");
    print(numbers.sum());
    print("numbers.min():");
    print(numbers.min());
    print("numbers.max():");
    print(numbers.max());
    print("numbers.for_each(print_item):");
    numbers.for_each(print_item);
    print("Chained: numbers.filter(is_even).map(dbl):");
    let chained = numbers.filter(is_even).map(dbl);
    print(chained);
    print("");
    // ── Iterator toolkit (itertools-style) ─────────────────
    print("═══ Iterator Toolkit ═══");
    print("");
    var items: List<int> = [1, 2, 3, 4, 5];

    print("items =");
    print(items);
    print("");

    print("items.combinations(2):");
    print(items.combinations(2));
    print("items.permutations(2):");
    print(items.permutations(2));
    print("");

    print("items.chunked(2):");
    print(items.chunked(2));
    print("items.chunked(3):");
    print(items.chunked(3));
    print("items.windowed(3):");
    print(items.windowed(3));
    print("items.pairwise():");
    print(items.pairwise());
    print("");

    print("items.reversed():");
    print(items.reversed());
    print("items.cycle(3):");
    print(items.cycle(3));
    print("");

    print("items.take_while(lt4):");
    print(items.take_while(lt4));
    print("items.drop_while(lt4):");
    print(items.drop_while(lt4));
    print("");

    // ── Generator + chaining composition ──────────────────
    print("═══ Generator + Chaining ═══");
    print("");

    print("Squares of count_to(6):");
    for x in count_to(6) {
        print(x * x);
    }
    print("");

    print("Even fib numbers < 100:");
    for x in fib_gen(100) {
        if x % 2 == 0 {
            print(x);
        }
    }
    print("");

    print("═══ Nim Showcase ═══");
    print("");

    // ── Person list + string concatenation (Nim fmt"{}") ──
    let people: List<Person> = [
        Person { name: "John", age: 45 },
        Person { name: "Kate", age: 30 }
    ];
    print("People:");
    for person in people {
        print(person.name + " is " + str(person.age) + " years old");
    }
    print("");

    // ── Filter-based iterator (Nim's "yield") ──
    print("Odd numbers from [3, 6, 9, 12, 15, 18]:");
    for odd in [3, 6, 9, 12, 15, 18].filter(is_odd) {
        print(odd);
    }
    print("");

    print("═══ Done ═══");
}
