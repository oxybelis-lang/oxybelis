// functools.ox - higher-order functions

pub fn reduce<T, F>(f: F, init: T, data: List<T>) -> T {
    var acc = init
    var i = 0
    while i < len(data) {
        acc = f(acc, data[i])
        i = i + 1
    }
    return acc
}
