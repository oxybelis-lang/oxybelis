// ────────────────────────────────────────────────────────────
//  glob.ox  –  Unix style pathname pattern expansion
//  Mirrors the Python `glob` module (subset).
//  Supports * and ? wildcards in a single path segment.
// ────────────────────────────────────────────────────────────

fn match_segment(name: str, pattern: str) -> bool {
    var ni = 0
    var pi = 0
    while pi < len(pattern) and ni <= len(name) {
        let pc = str_get(pattern, pi)
        if pc == "*" {
            var rest_ok = false
            var try_i = ni
            while try_i <= len(name) {
                if match_segment_rest(name, try_i, pattern, pi + 1) {
                    rest_ok = true
                    break
                }
                try_i = try_i + 1
            }
            return rest_ok
        }
        if ni >= len(name) { return false }
        if pc == "?" {
            ni = ni + 1
        } elif pc == str_get(name, ni) {
            ni = ni + 1
        } else {
            return false
        }
        pi = pi + 1
    }
    return pi == len(pattern) and ni == len(name)
}

fn match_segment_rest(name: str, from: int, pattern: str, pi: int) -> bool {
    var ni = from
    var pj = pi
    while pj < len(pattern) and ni <= len(name) {
        let pc = str_get(pattern, pj)
        if pc == "*" {
            var try_i = ni
            while try_i <= len(name) {
                if match_segment_rest(name, try_i, pattern, pj + 1) {
                    return true
                }
                try_i = try_i + 1
            }
            return false
        }
        if ni >= len(name) { return false }
        if pc == "?" {
            ni = ni + 1
        } elif pc == str_get(name, ni) {
            ni = ni + 1
        } else {
            return false
        }
        pj = pj + 1
    }
    return pj == len(pattern) and ni == len(name)
}

pub fn glob(pattern: str) -> List<str> {
    var parts: List<str> = []
    var start = 0
    var i = 0
    while i < len(pattern) {
        if str_get(pattern, i) == "/" {
            push(parts, str_sub(pattern, start, i))
            start = i + 1
        }
        i = i + 1
    }
    push(parts, str_sub(pattern, start, len(pattern)))

    var base: str = "."
    var candidates: List<str> = [""]
    var pi = 0
    while pi < len(parts) {
        let part = parts[pi]
        var has_wild = false
        var j = 0
        while j < len(part) {
            if str_get(part, j) == "*" or str_get(part, j) == "?" {
                has_wild = true
            }
            j = j + 1
        }
        var next: List<str> = []
        var ci = 0
        while ci < len(candidates) {
            let dir = candidates[ci]
            var full: str = base
            if dir != "" { full = full + "/" + dir }
            if has_wild {
                let entries = fs_list_dir(full)
                var ei = 0
                while ei < len(entries) {
                    let entry = entries[ei]
                    var name: str = entry
                    var slash = -1
                    var k = len(entry) - 1
                    while k >= 0 {
                        if str_get(entry, k) == "/" or str_get(entry, k) == "\\" {
                            slash = k
                            break
                        }
                        k = k - 1
                    }
                    if slash >= 0 { name = str_sub(entry, slash + 1, len(entry)) }
                    if match_segment(name, part) {
                        if dir == "" { push(next, name) }
                        else { push(next, dir + "/" + name) }
                    }
                    ei = ei + 1
                }
            } else {
                if dir == "" { push(next, part) }
                else { push(next, dir + "/" + part) }
            }
            ci = ci + 1
        }
        candidates = next
        pi = pi + 1
    }

    var result: List<str> = []
    var ri = 0
    while ri < len(candidates) {
        var full: str = base
        if candidates[ri] != "" { full = full + "/" + candidates[ri] }
        push(result, full)
        ri = ri + 1
    }
    return result
}
