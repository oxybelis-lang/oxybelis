import regex


fn is_nice(string: str) -> bool {
    if len(regex.find_all("[aeiou]", string)) < 3 {
        return false
    }
    if not regex.search("(.)\\1", string) {
        return false
    }
    if regex.search("ab|cd|pq|xy", string) {
        return false
    }
    return true
}

fn is_nice_v2(string: str) -> bool {
    return regex.search("(..).*\\1", string)
        and regex.search("(.).\\1", string)
}
        
fn main() -> void {
    let test: List<str> = [
        "ugknbfddgicrmopn",
        "jchzalrnumimnmhp",
        "haegwjzuvuyypxyu",
        "dvszwmarrgswjxmb",
    ]
    
    let strings = read_lines("day5.txt")
    print(strings.filter(is_nice).length())
    print(strings.filter(is_nice_v2).length())
}
