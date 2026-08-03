// ────────────────────────────────────────────────────────────
//  sys.ox  –  System-specific parameters and functions
//  Mirrors the Python `sys` module (subset).
// ────────────────────────────────────────────────────────────

pub let platform: str = _ox_platform()
pub let version: str = "Oxybelis 0.5.0"
pub let maxsize: long = 9223372036854775807

pub fn argv() -> List<str> {
    return args()
}

pub fn exit(code: int) {
    exit(code)
}

pub fn getrecursionlimit() -> int {
    return 1000
}

pub fn setrecursionlimit(n: int) {
}
