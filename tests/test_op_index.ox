// ── test_op_index.ox ──
// Tests: op_index and op_slice operator overloading

class Matrix {
    data: List<float>;
    rows: int;
    cols: int;

    fn op_index(self, i: int) -> float {
        return self.data[i]
    }

    fn op_slice(self, start: int, end: int, step: int) -> List<float> {
        return self.data[start:end:step]
    }
}

fn make_matrix(r: int, c: int) -> Matrix {
    return Matrix { data: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0], rows: r, cols: c }
}

fn main() {
    let m = make_matrix(3, 3)

    // op_index test
    print(m[0])
    print(m[4])
    print(m[8])

    // op_slice test
    let s = m[0:3:1]
    print(s)

    let s2 = m[::2]
    print(s2)

    // Direct list slice
    let v = m.data[2:5]
    print(v)

    print("done")
}
