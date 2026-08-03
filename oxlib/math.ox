// ────────────────────────────────────────────────────────────
//  math.ox  –  Python-style scalar math module
//  Mirrors the Python `math` module API: constants plus
//  per-element functions on scalars. Array operations live
//  in oxlib/numpy.ox (numpy.*).
// ────────────────────────────────────────────────────────────

pub let PI: float = 3.14159265358979323846
pub let E: float = 2.71828182845904523536
pub let TAU: float = 6.28318530717958647692
pub let inf: float = _ox_math_inf()
pub let nan: float = _ox_math_nan()

pub fn sqrt(x: float) -> float { return _ox_fsqrt(x) }
pub fn pow(x: float, y: float) -> float { return _ox_fpow(x, y) }
pub fn exp(x: float) -> float { return _ox_fexp(x) }
pub fn expm1(x: float) -> float { return _ox_fexp(x) - 1.0 }
pub fn log(x: float) -> float { return _ox_flog(x) }
pub fn log1p(x: float) -> float { return _ox_flog(1.0 + x) }
pub fn log2(x: float) -> float { return _ox_flog(x) / _ox_flog(2.0) }
pub fn log10(x: float) -> float { return _ox_flog(x) / _ox_flog(10.0) }

pub fn sin(x: float) -> float { return _ox_fsin(x) }
pub fn cos(x: float) -> float { return _ox_fcos(x) }
pub fn tan(x: float) -> float { return _ox_ftan(x) }
pub fn asin(x: float) -> float { return _ox_fasin(x) }
pub fn acos(x: float) -> float { return _ox_facos(x) }
pub fn atan(x: float) -> float { return _ox_fatan(x) }
pub fn atan2(y: float, x: float) -> float { return _ox_fatan2(y, x) }

pub fn sinh(x: float) -> float { return _ox_fsinh(x) }
pub fn cosh(x: float) -> float { return _ox_fcosh(x) }
pub fn tanh(x: float) -> float { return _ox_ftanh(x) }
pub fn asinh(x: float) -> float { return _ox_fasinh(x) }
pub fn acosh(x: float) -> float { return _ox_facosh(x) }
pub fn atanh(x: float) -> float { return _ox_fatanh(x) }

pub fn hypot(x: float, y: float) -> float { return sqrt(x * x + y * y) }
pub fn floor(x: float) -> float { return _ox_ffloor(x) }
pub fn ceil(x: float) -> float { return _ox_fceil(x) }
pub fn round(x: float) -> float { return _ox_fround(x) }
pub fn trunc(x: float) -> float { return float(int(x)) }
pub fn fabs(x: float) -> float { return _ox_fabs(x) }
pub fn copysign(x: float, y: float) -> float {
    if y >= 0.0 { return fabs(x) }
    return -fabs(x)
}
pub fn fmod(x: float, y: float) -> float { return x - y * floor(x / y) }
pub fn degrees(x: float) -> float { return x * 180.0 / PI }
pub fn radians(x: float) -> float { return x * PI / 180.0 }

pub fn erf(x: float) -> float { return _ox_ferf(x) }
pub fn erfc(x: float) -> float { return _ox_ferfc(x) }
pub fn gamma(x: float) -> float { return _ox_fgamma(x) }
pub fn lgamma(x: float) -> float { return _ox_flgamma(x) }

pub fn isnan(x: float) -> bool { return _ox_math_isnan(x) }
pub fn isinf(x: float) -> bool { return _ox_math_isinf(x) }
pub fn isfinite(x: float) -> bool { return _ox_math_isfinite(x) }

pub fn isclose(a: float, b: float, rel_tol: float, abs_tol: float) -> bool {
    if fabs(a - b) <= abs_tol { return true }
    return fabs(a - b) <= rel_tol * fabs(b)
}

pub fn gcd(a: int, b: int) -> int {
    var x = abs(a)
    var y = abs(b)
    while y != 0 {
        let t = x % y
        x = y
        y = t
    }
    return x
}

pub fn lcm(a: int, b: int) -> int {
    if a == 0 or b == 0 { return 0 }
    return abs(a / gcd(a, b) * b)
}

pub fn factorial(n: int) -> int {
    var result = 1
    var i = 2
    while i <= n {
        result = result * i
        i = i + 1
    }
    return result
}

pub fn comb(n: int, k: int) -> int {
    var kk = k
    if kk < 0 or kk > n { return 0 }
    if kk > n - kk { kk = n - kk }
    var result = 1
    var i = 0
    while i < kk {
        result = result * (n - i) / (i + 1)
        i = i + 1
    }
    return result
}

pub fn perm(n: int, k: int) -> int {
    if k < 0 or k > n { return 0 }
    var result = 1
    var i = 0
    while i < k {
        result = result * (n - i)
        i = i + 1
    }
    return result
}

pub fn dist(p: List<float>, q: List<float>) -> float {
    var total = 0.0
    var i = 0
    while i < len(p) {
        let d = p[i] - q[i]
        total = total + d * d
        i = i + 1
    }
    return sqrt(total)
}
