fn main() {
    // chaining: str_split -> map(to_int)
    let parts = str_split("1,2,3", ",")
    for x in parts {
        print(x)
    }
    let nums = parts.map(to_int)
    for n in nums {
        print(n)
    }

    // tuple unpacking
    let (a, b, c) = (10, 20, 30)
    print(a + b + c)
}
