// ── test_classes.ox ──
// Tests: classes, methods, struct literals, generics

class Point {
    x: int;
    y: int;
}

fn make_point(x: int, y: int) -> Point {
    return Point { x: x, y: y }
}

fn identity<T>(x: T) -> T { return x }

fn pair<T>(a: T, b: T) -> List<T> { return [a, b] }

fn main() {
    // ── class instantiation ──
    let p = make_point(3, 4)
    print(p.x)
    print(p.y)
    
    // ── struct literal directly ──
    let q = Point { x: 10, y: 20 }
    print(q.x)
    print(q.y)
    
    // ── generic identity function ──
    print(identity(42))
    print(identity("hello"))
    print(identity(3.14))
    print(identity(true))
    
    // ── generic pair ──
    let p2 = pair(1, 2)
    print(p2)
}
