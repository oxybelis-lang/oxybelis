// String formatting and utilities module
// Requires: import string

pub fn format(fmt: str, args: List<str>) -> str {
    return str_format(fmt, args)
}

pub fn pad_start(s: str, total_width: int, pad_char: str) -> str {
    let n: int = total_width - len(s)
    if n <= 0 { return s }
    return str_repeat(pad_char, n) + s
}

pub fn pad_end(s: str, total_width: int, pad_char: str) -> str {
    let n: int = total_width - len(s)
    if n <= 0 { return s }
    return s + str_repeat(pad_char, n)
}

pub fn center(s: str, width: int, pad_char: str) -> str {
    let n: int = width - len(s)
    if n <= 0 { return s }
    let left: int = n / 2
    let right: int = n - left
    return str_repeat(pad_char, left) + s + str_repeat(pad_char, right)
}

pub fn quote(s: str) -> str {
    return "\"" + s + "\""
}

pub fn lines(s: str) -> List<str> {
    return str_split(s, "\n")
}

pub fn from_lines(lines: List<str>, delim: str) -> str {
    return str_join(lines, delim)
}
