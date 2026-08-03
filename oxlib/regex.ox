// ────────────────────────────────────────────────────────────
//  regex.ox  –  Regular expression operations
// ────────────────────────────────────────────────────────────

pub fn compile(pattern: str) -> Regex {
    return _ox_regex_compile(pattern);
}

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

pub fn groups(pattern: str, s: str) -> List<List<str>> {
    return _ox_regex_groups(pattern, s);
}

pub fn groups_re(re: Regex, s: str) -> List<List<str>> {
    return _ox_regex_groups_re(re, s);
}

pub fn groups_iter(pattern: str, s: str) -> Generator<List<str>> {
    return _ox_regex_groups_iter(pattern, s);
}

pub fn groups_iter_re(re: Regex, s: str) -> Generator<List<str>> {
    return _ox_regex_groups_iter_re(re, s);
}

pub fn replace(pattern: str, s: str, replacement: str) -> str {
    return _ox_regex_replace(pattern, s, replacement);
}

pub fn split(pattern: str, s: str) -> List<str> {
    return _ox_regex_split(pattern, s);
}
