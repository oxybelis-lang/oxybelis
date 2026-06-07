fn main() -> void {
    let parts = str_split("1,2,3", ",")
    for x in parts {
        print(x)
    }
    let nums = parts.map(to_int)
    for n in nums {
        print(n)
    }
}
