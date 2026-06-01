// ────────────────────────────────────────────────────────────
//  json.ox  –  JSON parser
// ────────────────────────────────────────────────────────────

class ParseVal {
    v: str;
    next: int;
}

fn skip_ws(s: str, i: int) -> int {
    while i < len(s) {
        let c: str = str_get(s, i);
        if c == " " or c == "\t" or c == "\n" or c == "\r" {
            i = i + 1;
        } else { break; }
    }
    return i;
}

fn parse_str_raw(s: str, start: int) -> Option<ParseVal> {
    if str_get(s, start) != "\"" { return None; }
    var i = start + 1;
    var val: str = "";
    while i < len(s) {
        let c: str = str_get(s, i);
        if c == "\"" {
            i = i + 1;
            return Some(ParseVal { v: val, next: i });
        }
        if c == "\\" {
            i = i + 1;
            let esc: str = str_get(s, i);
            if esc == "n" { val = val + "\n"; }
            elif esc == "t" { val = val + "\t"; }
            elif esc == "\\" { val = val + "\\"; }
            elif esc == "\"" { val = val + "\""; }
            elif esc == "r" { val = val + "\r"; }
            else { val = val + esc; }
        } else {
            val = val + c;
        }
        i = i + 1;
    }
    return None;
}

fn parse_number(s: str, start: int) -> Option<ParseVal> {
    var i = start;
    if str_get(s, i) == "-" { i = i + 1; }
    if i >= len(s) or not is_digit(str_get(s, i)) { return None; }
    while i < len(s) and is_digit(str_get(s, i)) { i = i + 1; }
    if i < len(s) and str_get(s, i) == "." {
        i = i + 1;
        while i < len(s) and is_digit(str_get(s, i)) { i = i + 1; }
    }
    let num_str: str = str_sub(s, start, i);
    return Some(ParseVal { v: num_str, next: i });
}

fn parse_value(s: str, start: int) -> Option<ParseVal> {
    let i = skip_ws(s, start);
    if i >= len(s) { return None; }
    let c: str = str_get(s, i);

    if c == "\"" {
        return parse_str_raw(s, i);
    }
    if c == "t" and (i + 4) <= len(s) and str_sub(s, i, i + 4) == "true" {
        return Some(ParseVal { v: "true", next: i + 4 });
    }
    if c == "f" and (i + 5) <= len(s) and str_sub(s, i, i + 5) == "false" {
        return Some(ParseVal { v: "false", next: i + 5 });
    }
    if c == "n" and (i + 4) <= len(s) and str_sub(s, i, i + 4) == "null" {
        return Some(ParseVal { v: "null", next: i + 4 });
    }
    if c == "-" or is_digit(c) {
        return parse_number(s, i);
    }
    return None;
}

pub fn parse(s: str) -> Option<str> {
    let i = skip_ws(s, 0);
    let r = parse_value(s, i);
    if r == None { return None; }
    return Some(r.value.v);
}

pub fn parse_str(s: str) -> Option<str> {
    let i = skip_ws(s, 0);
    let r = parse_str_raw(s, i);
    if r == None { return None; }
    return Some(r.value.v);
}

pub fn parse_float(s: str) -> Option<float> {
    let i = skip_ws(s, 0);
    let r = parse_number(s, i);
    if r == None { return None; }
    return Some(to_float(r.value.v));
}

pub fn escape(s: str) -> str {
    var result: str = "\"";
    var i = 0;
    while i < len(s) {
        let c: str = str_get(s, i);
        if c == "\\" { result = result + "\\\\"; }
        elif c == "\"" { result = result + "\\\""; }
        elif c == "\n" { result = result + "\\n"; }
        elif c == "\t" { result = result + "\\t"; }
        elif c == "\r" { result = result + "\\r"; }
        else { result = result + c; }
        i = i + 1;
    }
    return result + "\"";
}
