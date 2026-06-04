// ────────────────────────────────────────────────────────────
//  examples/classes.ox  –  Classes, methods, struct-like usage
// ────────────────────────────────────────────────────────────

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

fn main() {
    print("═══ Classes Demo ═══");
    print("");

    // Vector2
    let v1 = Vector2 { x: 3.0, y: 4.0 };
    let v2 = Vector2 { x: 1.0, y: 2.0 };
    print("v1 length:");
    print(v1.length());
    let v3 = v1.add(v2);
    print("v1 + v2 =");
    print(v3.x);
    print(v3.y);
    print("v1 dot v2 =");
    print(v1.dot(v2));
    print("");

    // Counter
    var c: Counter = Counter { value: 0 };
    c.increment();
    c.increment();
    c.increment();
    c.decrement();
    print("Counter after +3 -1:");
    print(c.get());
    c.reset();
    print("Counter after reset:");
    print(c.get());
    print("");

    // Person struct
    let p = Person { name: "Alice", age: 30 };
    print("Person:");
    print(p.name);
    print(p.age);
    print("");

    print("═══ Done ═══");
}
