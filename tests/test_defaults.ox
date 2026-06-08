fn greet(name: str, greeting: str = "Hello") -> void {
    print(greeting + ", " + name + "!")
}

fn add(a: int, b: int = 10) -> int {
    return a + b
}

fn main() -> void {
    greet("Alice")
    greet("Bob", "Hi")
    print(add(5))
    print(add(5, 20))
}
