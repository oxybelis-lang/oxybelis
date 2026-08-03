// ────────────────────────────────────────────────────────────
//  time.ox  –  Time access and conversions
//  Mirrors the Python `time` module (subset).
//  localtime()/gmtime() return List<int>:
//  [year, month, day, hour, minute, second, weekday, yearday]
// ────────────────────────────────────────────────────────────

pub fn time() -> float {
    return _ox_time_epoch()
}

pub fn monotonic() -> float {
    return _ox_time_epoch()
}

pub fn perf_counter() -> float {
    return _ox_perf_counter()
}

pub fn sleep(seconds: float) {
    _ox_sleep(seconds)
}

pub fn localtime() -> List<int> {
    return _ox_localtime()
}

pub fn gmtime() -> List<int> {
    return _ox_gmtime()
}

fn pad2(n: int) -> str {
    if n < 10 { return "0" + str(n) }
    return str(n)
}

pub fn strftime(fmt: str, t: List<int>) -> str {
    var r: str = fmt
    r = str_replace(r, "%Y", str(t[0]))
    r = str_replace(r, "%m", pad2(t[1]))
    r = str_replace(r, "%d", pad2(t[2]))
    r = str_replace(r, "%H", pad2(t[3]))
    r = str_replace(r, "%M", pad2(t[4]))
    r = str_replace(r, "%S", pad2(t[5]))
    r = str_replace(r, "%j", pad2(t[7]))
    r = str_replace(r, "%w", str(t[6]))
    r = str_replace(r, "%%", "%")
    return r
}
