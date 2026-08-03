import math
import numpy

fn main() {
    // ── Scalar math (Python-style) ──
    print(math.PI)
    print(math.E)
    print(math.sqrt(2.0))
    print(math.pow(2.0, 10.0))
    print(math.sin(math.PI / 2.0))
    print(math.log(math.E))
    print(math.floor(3.7))
    print(math.ceil(3.2))
    print(math.fabs(-2.5))
    print(math.factorial(5))
    print(math.gcd(12, 18))
    print(math.hypot(3.0, 4.0))
    print(math.degrees(math.PI))
    print(math.isnan(math.nan))
    print(math.isinf(math.inf))

    // ── Array creation ──
    let z = numpy.zeros(5)
    print(z)
    
    let o = numpy.ones(3)
    print(o)

    let ls = numpy.linspace(0.0, 1.0, 5)
    print(ls)

    let ar = numpy.arange(0.0, 5.0, 1.0)
    print(ar)

    // ── Element-wise ──
    let a = numpy.linspace(0.0, 6.28, 5)
    let s = numpy.sin(a)
    print(s)

    let c = numpy.cos(a)
    print(c)

    // ── Arithmetic ──
    let x = numpy.array([1.0, 2.0, 3.0])
    let y = numpy.array([4.0, 5.0, 6.0])
    print(numpy.add(x, y))
    print(numpy.sub(x, y))
    print(numpy.mul(x, y))
    print(numpy.div(x, y))

    // ── Reductions ──
    let data = numpy.array([1.0, 2.0, 3.0, 4.0, 5.0])
    print(numpy.sum(data))
    print(numpy.mean(data))
    print(numpy.min(data))
    print(numpy.max(data))

    // ── Linear algebra ──
    let v1 = numpy.array([1.0, 2.0, 3.0])
    let v2 = numpy.array([4.0, 5.0, 6.0])
    print(numpy.dot(v1, v2))

    let m = numpy.eye(3)
    print(m)
    
    let m2 = numpy.transpose(m)
    print(m2)
}
