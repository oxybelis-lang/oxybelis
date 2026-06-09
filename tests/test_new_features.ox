fn main() {
    // 1. Type casts
    print(int(3.14))
    print(float(42))
    print(bool(1))
    print(bool(0))

    // 2. Base-N parsing
    print(parse_int("FF", 16))
    print(parse_int("1010", 2))
    print(parse_int("77", 8))
    print(parse_int("255", 10))

    // 3. str_format with format specs
    print(str_format("{:.2f}", ["3.14159"]))
    print(str_format("{:x}", ["255"]))
    print(str_format("{:X}", ["255"]))
    print(str_format("{:o}", ["255"]))
    print(str_format("{:b}", ["255"]))
    print(str_format("|{:>10}|", ["hi"]))
    print(str_format("|{:<10}|", ["hi"]))
    print(str_format("|{:^10}|", ["hi"]))
    print(str_format("{:.3e}", ["3.14159"]))
}
