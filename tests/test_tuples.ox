fn main() {
    // Basic tuple literal
    let t = (1, "hello", true)
    print(t.0)
    print(t.1)
    print(t.2)

    // Tuple type annotation
    let p: (str, int) = ("answer", 42)
    print(p.0)
    print(p.1)

    // Single-element tuple (trailing comma)
    let s = (99,)
    print(s.0)

    // Tuple unpacking in let
    let (a, b, c) = (10, 20, 30)
    print(a)
    print(b)
    print(c)

    // enumerate on list
    let v = ["a", "b", "c"]
    for (idx, ele) in enumerate(v) {
        print(idx)
        print(ele)
    }

    // enumerate on string
    for (i, ch) in enumerate("abc") {
        print(i)
        print(ch)
    }

    // sorted on list
    let nums = [3, 1, 4, 1, 5]
    let sorted_nums = sorted(nums)
    for x in sorted_nums {
        print(x)
    }

    // sorted on string
    for ch in sorted("cba") {
        print(ch)
    }
}
