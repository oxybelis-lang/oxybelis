// ────────────────────────────────────────────────────────────
//  examples/nim_like.ox  –  Nim-style features in Oxybelis
// ────────────────────────────────────────────────────────────

class Person {
    name: str;
    age: int;
}

fn is_odd(x: int) -> bool {
    return x % 2 == 1;
}

fn main() {
    print("═══ Nim-style Showcase ═══");
    print("");

    // ── List of objects with string formatting ──
    let people: List<Person> = [
        Person { name: "John", age: 45 },
        Person { name: "Kate", age: 30 }
    ];
    print("People:");
    for person in people {
        print(person.name + " is " + str(person.age) + " years old");
    }
    print("");

    // ── Filter-based iteration (like Nim's iterator + yield) ──
    print("Odd numbers from [3, 6, 9, 12, 15, 18]:");
    for odd in [3, 6, 9, 12, 15, 18].filter(is_odd) {
        print(odd);
    }
    print("");

    print("═══ Done ═══");
}
