// ────────────────────────────────────────────────────────────
//  datetime.ox  –  Date and time operations
// ────────────────────────────────────────────────────────────

pub fn now() -> str {
    return _ox_datetime_now();
}

pub fn format(dt: str, fmt: str) -> str {
    return _ox_datetime_format(dt, fmt);
}

pub fn parse(s: str, fmt: str) -> str {
    return _ox_datetime_parse(s, fmt);
}

pub fn year(dt: str) -> int {
    return _ox_datetime_component(dt, 0);
}

pub fn month(dt: str) -> int {
    return _ox_datetime_component(dt, 1);
}

pub fn day(dt: str) -> int {
    return _ox_datetime_component(dt, 2);
}

pub fn hour(dt: str) -> int {
    return _ox_datetime_component(dt, 3);
}

pub fn minute(dt: str) -> int {
    return _ox_datetime_component(dt, 4);
}

pub fn second(dt: str) -> int {
    return _ox_datetime_component(dt, 5);
}
