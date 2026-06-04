// ────────────────────────────────────────────────────────────
//  math.ox  –  NumCpp-powered math library
//  Provides numpy-like functionality using NumCpp under the hood.
//  Uses List<float> as the public 1D array type and
//  List<List<float>> as the public 2D array type.
// ────────────────────────────────────────────────────────────

pub fn array(data: List<float>) -> List<float> { return data }
pub fn zeros(n: int) -> List<float> { return _ox_math_zeros(n) }
pub fn ones(n: int) -> List<float> { return _ox_math_ones(n) }
pub fn linspace(start: float, end: float, n: int) -> List<float> { return _ox_math_linspace(start, end, n) }
pub fn arange(start: float, end: float, step: float) -> List<float> { return _ox_math_arange(start, end, step) }

pub fn dot(a: List<float>, b: List<float>) -> float { return _ox_math_dot(a, b) }
pub fn matmul(a: List<List<float>>, b: List<List<float>>) -> List<List<float>> { return _ox_math_matmul(a, b) }
pub fn transpose(a: List<List<float>>) -> List<List<float>> { return _ox_math_transpose(a) }
pub fn norm(a: List<float>) -> float { return _ox_math_norm(a) }
pub fn inv(a: List<List<float>>) -> List<List<float>> { return _ox_math_inv(a) }
pub fn det(a: List<List<float>>) -> float { return _ox_math_det(a) }
pub fn solve(A: List<List<float>>, b: List<float>) -> List<float> { return _ox_math_solve(A, b) }

pub fn sin(a: List<float>) -> List<float> { return _ox_math_sin(a) }
pub fn cos(a: List<float>) -> List<float> { return _ox_math_cos(a) }
pub fn tan(a: List<float>) -> List<float> { return _ox_math_tan(a) }
pub fn sqrt(a: List<float>) -> List<float> { return _ox_math_sqrt(a) }
pub fn abs(a: List<float>) -> List<float> { return _ox_math_abs(a) }
pub fn exp(a: List<float>) -> List<float> { return _ox_math_exp(a) }
pub fn log(a: List<float>) -> List<float> { return _ox_math_log(a) }
pub fn floor(a: List<float>) -> List<float> { return _ox_math_floor(a) }
pub fn ceil(a: List<float>) -> List<float> { return _ox_math_ceil(a) }

pub fn add(a: List<float>, b: List<float>) -> List<float> { return _ox_math_add(a, b) }
pub fn sub(a: List<float>, b: List<float>) -> List<float> { return _ox_math_sub(a, b) }
pub fn mul(a: List<float>, b: List<float>) -> List<float> { return _ox_math_mul(a, b) }
pub fn div(a: List<float>, b: List<float>) -> List<float> { return _ox_math_div(a, b) }

pub fn sum(a: List<float>) -> float { return _ox_math_sum(a) }
pub fn mean(a: List<float>) -> float { return _ox_math_mean(a) }
pub fn min(a: List<float>) -> float { return _ox_math_min(a) }
pub fn max(a: List<float>) -> float { return _ox_math_max(a) }

pub fn reshape(a: List<float>, rows: int, cols: int) -> List<float> { return _ox_math_reshape(a, rows, cols) }

pub fn eye(n: int) -> List<List<float>> {
    var result: List<List<float>> = []
    var i = 0
    while i < n {
        var row: List<float> = []
        var j = 0
        while j < n {
            if i == j { push(row, 1.0) }
            else { push(row, 0.0) }
            j = j + 1
        }
        push(result, row)
        i = i + 1
    }
    return result
}
