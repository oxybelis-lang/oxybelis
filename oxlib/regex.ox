// ────────────────────────────────────────────────────────────
//  regex.ox  –  Regular expression operations
// ────────────────────────────────────────────────────────────

pub fn matches(pattern: str, s: str) -> bool {
    return _ox_regex_match(pattern, s);
}

pub fn search(pattern: str, s: str) -> bool {
    return _ox_regex_search(pattern, s);
}

pub fn find(pattern: str, s: str) -> Option<str> {
    let r = _ox_regex_find(pattern, s);
    if r == "" { return None; }
    return Some(r);
}

pub fn find_all(pattern: str, s: str) -> List<str> {
    return _ox_regex_find_all(pattern, s);
}

pub fn replace(pattern: str, s: str, replacement: str) -> str {
    return _ox_regex_replace(pattern, s, replacement);
}

pub fn split(pattern: str, s: str) -> List<str> {
    return _ox_regex_split(pattern, s);
}
