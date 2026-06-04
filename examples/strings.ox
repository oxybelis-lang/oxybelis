// ────────────────────────────────────────────────────────────
//  examples/strings.ox  –  String stdlib functions
// ────────────────────────────────────────────────────────────

fn main() {
    print("═══ Strings Demo ═══");
    print("");

    // split
    print("str_split('a,b,c', ','):");
    print(str_split("a,b,c", ","));

    // trim
    print("str_trim('  hello  '):");
    print("'" + str_trim("  hello  ") + "'");
    print("str_trim_start('  hello  '):");
    print("'" + str_trim_start("  hello  ") + "'");
    print("str_trim_end('  hello  '):");
    print("'" + str_trim_end("  hello  ") + "'");

    // replace
    print("str_replace('hello world', 'world', 'there'):");
    print(str_replace("hello world", "world", "there"));
    print("str_replace_all('a-b-c', '-', '/'):");
    print(str_replace_all("a-b-c", "-", "/"));

    // join
    print("str_join(['a', 'b', 'c'], ','):");
    print(str_join(["a", "b", "c"], ","));
    print("str_join(['x'], '---'):");
    print(str_join(["x"], "---"));

    // to_upper / to_lower
    print("to_upper('Hello World'):");
    print(to_upper("Hello World"));
    print("to_lower('Hello World'):");
    print(to_lower("Hello World"));

    // starts_with / ends_with
    print("starts_with('hello', 'he'):");
    print(starts_with("hello", "he"));
    print("starts_with('hello', 'xyz'):");
    print(starts_with("hello", "xyz"));
    print("ends_with('hello', 'lo'):");
    print(ends_with("hello", "lo"));
    print("ends_with('hello', 'la'):");
    print(ends_with("hello", "la"));

    // repeat
    print("str_repeat('ha', 3):");
    print(str_repeat("ha", 3));

    // reverse
    print("str_reverse('hello'):");
    print(str_reverse("hello"));

    // find
    print("str_find('hello world', 'world'):");
    print(str_find("hello world", "world"));
    print("str_find('hello world', 'xyz'):");
    print(str_find("hello world", "xyz"));

    print("");
    print("═══ Done ═══");
}
