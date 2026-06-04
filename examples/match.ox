// ────────────────────────────────────────────────────────────
//  examples/match.ox  –  Pattern matching
// ────────────────────────────────────────────────────────────

fn classify(n: int) -> str {
    match n {
        0 => return "zero";
        1..10 => return "small   (1-9)";
        10..100 => return "medium  (10-99)";
        _ => return "large   (100+)";
    }
    return "";
}

fn http_status(code: int) -> str {
    match code {
        200 => return "OK";
        201 => return "Created";
        400 => return "Bad Request";
        401 => return "Unauthorized";
        403 => return "Forbidden";
        404 => return "Not Found";
        500 => return "Internal Server Error";
        _ => return "Unknown";
    }
    return "";
}

fn main() {
    print("═══ Match Demo ═══");
    print("");

    print("classify(0)   =");
    print(classify(0));
    print("classify(7)   =");
    print(classify(7));
    print("classify(55)  =");
    print(classify(55));
    print("classify(200) =");
    print(classify(200));
    print("");

    print("HTTP 200 =");
    print(http_status(200));
    print("HTTP 404 =");
    print(http_status(404));
    print("HTTP 500 =");
    print(http_status(500));
    print("HTTP 999 =");
    print(http_status(999));
    print("");

    print("═══ Done ═══");
}
