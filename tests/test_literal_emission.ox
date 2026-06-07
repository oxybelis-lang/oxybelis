fn echo<T>(x: T) -> T {
    return x
}

fn sum_list(xs: List<int>) -> int {
    let s: int = 0
    let i: int = 0
    while i < len(xs) {
        s = s + xs[i]
        i = i + 1
    }
    return s
}

fn main() {
    print(echo("hello"))
    print(echo("world"))
    print(sum_list([1,2,3]))
    let v: List<int> = [4,5,6]
    print(sum_list(v))
}
