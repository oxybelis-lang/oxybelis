// ── test_slicing.ox ──
// Tests: Python-style slicing syntax [start:end:step]

fn main() {
    let v = [0, 1, 2, 3, 4, 5]
    print(v)

    // Simple index
    print(v[1])

    // [:] — full slice (start to end)
    let all = v[:]
    print(all)

    // [1:] — from index 1 to end
    let from1 = v[1:]
    print(from1)

    // [:3] — from start to index 3 (exclusive)
    let to3 = v[:3]
    print(to3)

    // [::2] — every other element
    let step2 = v[::2]
    print(step2)

    // [1::2] — from index 1, every other
    let step2b = v[1::2]
    print(step2b)

    // [2:5] — slice from 2 to 5 (exclusive)
    let slice25 = v[2:5]
    print(slice25)

    // [1:5:2] — slice from 1 to 5, every 2nd
    let slice152 = v[1:5:2]
    print(slice152)
}
