fn main() {
    // str method calls -> redirected to free functions
    let s = "hello world"
    print(s.length())
    print(s.contains("world"))
    print(s.starts_with("hello"))
    print(s.ends_with("world"))
    print(s.count("o"))
    print(s.find("world"))
    print(s.to_upper())
    print(s.to_lower())
    print(s.replace("world", "there"))
    print(s.reverse())

    // List method calls -> redirected to free functions
    let v = [1, 2, 3, 2, 1]
    print(v.length())
    print(v.contains(3))
    print(v.count(2))

    // list() conversion from string
    let chars = list("abc")
    print(chars.length())
    print(chars[0])
    print(chars[1])
    print(chars[2])

    // for loop over string
    for c in "hi" {
        print(c)
    }

    print("done")
}
