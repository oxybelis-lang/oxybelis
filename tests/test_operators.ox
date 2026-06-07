// ── test_operators.ox ──
// Tests: operator overloading (op_add, op_sub, op_mul, etc.)

class Vec2 {
    x: float;
    y: float;

    fn op_add(self, other: Vec2) -> Vec2 {
        return Vec2 { x: self.x + other.x, y: self.y + other.y }
    }
    fn op_sub(self, other: Vec2) -> Vec2 {
        return Vec2 { x: self.x - other.x, y: self.y - other.y }
    }
    fn op_mul(self, scalar: float) -> Vec2 {
        return Vec2 { x: self.x * scalar, y: self.y * scalar }
    }
}

fn main() {
    let a = Vec2 { x: 1.0, y: 2.0 }
    let b = Vec2 { x: 3.0, y: 4.0 }

    // op_add
    let c = a + b
    print(c.x)
    print(c.y)

    // op_sub
    let d = a - b
    print(d.x)
    print(d.y)

    // op_mul
    let e = a * 2.0
    print(e.x)
    print(e.y)
}
