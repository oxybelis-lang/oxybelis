fn first<T>(xs: List<T>) -> T {
    return xs[0]
}

fn flatten<T>(x: List<List<T>>) -> List<T> {
    let r: List<T> = []
    let i = 0
    while i < len(x) {
        let inner = x[i]
        let j = 0
        while j < len(inner) {
            push(r, inner[j])
            j = j + 1
        }
        i = i + 1
    }
    return r
}

fn main() {
    // simple generic: first on List<int>
    print(first([1,2,3]))

    // nested list literal passed to generic expecting List<List<int>>
    print(first([[1,2],[3,4]]))

    // typed variable with nested lists
    let v: List<List<int>> = [[5,6],[7,8]]
    print(first(v))

    // flatten a nested literal
    print(flatten([[9,10],[11]]))
}
