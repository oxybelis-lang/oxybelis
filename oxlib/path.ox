// ────────────────────────────────────────────────────────────
//  path.ox  –  Path manipulation utilities
// ────────────────────────────────────────────────────────────

pub fn path_join(parts: List<str>) -> str {
    var result: str = "";
    var i: int = 0;
    while i < len(parts) {
        let part: str = parts[i];
        if len(part) > 0 {
            if len(result) > 0 and str_get(result, len(result) - 1) != "/" {
                result = result + "/";
            }
            result = result + part;
        }
        i = i + 1;
    }
    return result;
}

pub fn path_split(path: str) -> List<str> {
    var parts: List<str> = List<str>();
    var start: int = 0;
    var i: int = 0;
    while i < len(path) {
        if str_get(path, i) == "/" {
            if i > start {
                push(parts, str_sub(path, start, i));
            }
            start = i + 1;
        }
        i = i + 1;
    }
    if start < len(path) {
        push(parts, str_sub(path, start, len(path)));
    }
    return parts;
}

pub fn path_dirname(path: str) -> str {
    var i: int = len(path) - 1;
    while i >= 0 {
        if str_get(path, i) == "/" {
            if i == 0 { return "/"; }
            return str_sub(path, 0, i);
        }
        i = i - 1;
    }
    return "";
}

pub fn path_basename(path: str) -> str {
    var i: int = len(path) - 1;
    while i >= 0 {
        if str_get(path, i) == "/" {
            return str_sub(path, i + 1, len(path));
        }
        i = i - 1;
    }
    return path;
}

pub fn path_stem(path: str) -> str {
    var name: str = path_basename(path);
    var i: int = len(name) - 1;
    while i >= 0 {
        if str_get(name, i) == "." {
            if i == 0 { return name; }
            return str_sub(name, 0, i);
        }
        i = i - 1;
    }
    return name;
}

pub fn path_ext(path: str) -> str {
    var name: str = path_basename(path);
    var i: int = len(name) - 1;
    while i >= 0 {
        if str_get(name, i) == "." {
            if i == 0 { return ""; }
            return str_sub(name, i, len(name));
        }
        i = i - 1;
    }
    return "";
}

pub fn path_normalize(path: str) -> str {
    let is_abs: bool = len(path) > 0 and str_get(path, 0) == "/";
    var parts: List<str> = path_split(path);
    var result: List<str> = List<str>();
    var i: int = 0;
    while i < len(parts) {
        if parts[i] == "." {
            // skip
        } elif parts[i] == ".." and len(result) > 0 {
            pop(result);
        } elif parts[i] != ".." {
            push(result, parts[i]);
        }
        i = i + 1;
    }
    var joined: str = path_join(result);
    if is_abs { joined = "/" + joined; }
    if joined == "" { joined = "."; }
    return joined;
}
