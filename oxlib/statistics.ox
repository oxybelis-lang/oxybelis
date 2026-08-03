// ────────────────────────────────────────────────────────────
//  statistics.ox  –  Mathematical statistics functions
//  Mirrors the Python `statistics` module (subset).
//  All data arguments are List<float>.
// ────────────────────────────────────────────────────────────

pub fn mean(data: List<float>) -> float {
    return _ox_math_sum(data) / float(len(data))
}

pub fn fmean(data: List<float>) -> float {
    return mean(data)
}

pub fn median(data: List<float>) -> float {
    let s = sorted(data)
    let n = len(s)
    if n == 0 { return 0.0 }
    if n % 2 == 1 { return s[n / 2] }
    return (s[n / 2 - 1] + s[n / 2]) / 2.0
}

pub fn median_low(data: List<float>) -> float {
    let s = sorted(data)
    let n = len(s)
    if n == 0 { return 0.0 }
    return s[(n - 1) / 2]
}

pub fn median_high(data: List<float>) -> float {
    let s = sorted(data)
    let n = len(s)
    if n == 0 { return 0.0 }
    return s[n / 2]
}

pub fn mode(data: List<float>) -> float {
    var best = data[0]
    var best_count = 0
    var i = 0
    while i < len(data) {
        var c = 0
        var j = 0
        while j < len(data) {
            if data[j] == data[i] { c = c + 1 }
            j = j + 1
        }
        if c > best_count {
            best = data[i]
            best_count = c
        }
        i = i + 1
    }
    return best
}

pub fn variance(data: List<float>) -> float {
    let m = mean(data)
    var total = 0.0
    var i = 0
    while i < len(data) {
        let d = data[i] - m
        total = total + d * d
        i = i + 1
    }
    return total / float(len(data) - 1)
}

pub fn pvariance(data: List<float>) -> float {
    let m = mean(data)
    var total = 0.0
    var i = 0
    while i < len(data) {
        let d = data[i] - m
        total = total + d * d
        i = i + 1
    }
    return total / float(len(data))
}

pub fn stdev(data: List<float>) -> float {
    return _ox_fsqrt(variance(data))
}

pub fn pstdev(data: List<float>) -> float {
    return _ox_fsqrt(pvariance(data))
}

pub fn quantiles(data: List<float>, n: int) -> List<float> {
    let s = sorted(data)
    let m = len(s)
    var result: List<float> = []
    var k = 1
    while k < n {
        let pos = float(m) * float(k) / float(n) - 0.5
        var idx = int(pos)
        if float(idx) < pos {
            let frac = pos - float(idx)
            let lo = s[idx]
            let hi = s[idx + 1]
            push(result, lo + frac * (hi - lo))
        } else {
            push(result, s[idx])
        }
        k = k + 1
    }
    return result
}
