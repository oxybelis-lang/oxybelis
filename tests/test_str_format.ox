import string

fn main() {
    // Direct builtin
    let r1 = str_format("Hello {}!", ["world"])
    print(r1)

    let parts: List<str> = ["a", "b", "c"]
    let r2 = str_format("{} + {} + {}", parts)
    print(r2)

    // Module wrapper
    let r3 = string.format("Value: {}", ["42"])
    print(r3)

    // Edge cases: no placeholders
    let r4 = str_format("plain", List<str>())
    print(r4)

    // More args than placeholders
    let r5 = str_format("{} {}", ["x", "y", "z"])
    print(r5)

    // Fewer args than placeholders
    let r6 = str_format("{} {} {}", ["only"])
    print(r6)

    // Pad/center
    let name = "ox"
    print(string.pad_end(name, 10, "-"))

    let msg = "hello"
    print(string.pad_start(msg, 10, " "))
    print(string.center(msg, 11, "*"))
}
