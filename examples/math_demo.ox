import math

fn main() {
    // ── Array creation ──
    let z = math.zeros(5)
    print(z)

    let o = math.ones(3)
    print(o)

    let ls = math.linspace(0.0, 1.0, 5)
    print(ls)

    let ar = math.arange(0.0, 5.0, 1.0)
    print(ar)

    // ── Element-wise ──
    let a = math.linspace(0.0, 6.28, 5)
    let s = math.sin(a)
    print(s)

    let c = math.cos(a)
    print(c)

    // ── Arithmetic ──
    let x = math.array([1.0, 2.0, 3.0])
    let y = math.array([4.0, 5.0, 6.0])
    print(math.add(x, y))
    print(math.sub(x, y))
    print(math.mul(x, y))
    print(math.div(x, y))

    // ── Reductions ──
    let data = math.array([1.0, 2.0, 3.0, 4.0, 5.0])
    print(math.sum(data))
    print(math.mean(data))
    print(math.min(data))
    print(math.max(data))

    // ── Linear algebra ──
    let v1 = math.array([1.0, 2.0, 3.0])
    let v2 = math.array([4.0, 5.0, 6.0])
    print(math.dot(v1, v2))

    let m = math.eye(3)
    print(m)
    
    let m2 = math.transpose(m)
    print(m2)
}

fn math_array_private(data: List<float>) -> List<float> {
    return data
}
