// ────────────────────────────────────────────────────────────
//  timeit.ox  –  Execution timing utilities
//
//  Usage:
//    import timeit
//
//    fn my_code() { ... }
//
//    let t = timeit.Timer(my_code)
//    print(t.timeit(1000))
//
//    # With setup function:
//    fn setup() { ... }
//    let t2 = timeit.TimerWithSetup(my_code, setup)
//    print(t2.timeit(1000))
//
//    # Convenience:
//    print(timeit.timeit(my_code, 1000))
// ────────────────────────────────────────────────────────────

pub fn default_timer() -> float {
    return _ox_perf_counter()
}

pub class SimpleTimerClass<S> {
    _stmt: S

    pub fn timeit(self, number: int) -> float {
        return _ox_timeit(self._stmt, number)
    }
}

pub class TimerWithSetupClass<S, T> {
    _stmt: S
    _setup: T

    pub fn timeit(self, number: int) -> float {
        return _ox_timeit_setup(self._setup, self._stmt, number)
    }
}

pub fn Timer<S>(stmt: S) -> SimpleTimerClass<S> {
    return SimpleTimerClass<S> { _stmt: stmt }
}

pub fn TimerWithSetup<S, T>(stmt: S, setup: T) -> TimerWithSetupClass<S, T> {
    return TimerWithSetupClass<S, T> { _stmt: stmt, _setup: setup }
}

pub fn timeit<S>(stmt: S, number: int) -> float {
    return _ox_timeit(stmt, number)
}
