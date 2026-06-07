// Random number generation module
// Requires: import random
// Note: Seed is auto-initialized from std::random_device at startup

pub fn randint(a: int, b: int) -> int {
    return _ox_randint(a, b)
}

pub fn randrange(start: int, stop: int) -> int {
    return _ox_randint(start, stop - 1)
}

pub fn random() -> float {
    return _ox_randfloat()
}

pub fn seed(s: int) -> void {
    _ox_randseed(s)
}

pub fn choice<T>(items: List<T>) -> Option<T> {
    let n: int = len(items)
    if n == 0 { return None }
    return Some(items[_ox_randint(0, n - 1)])
}
