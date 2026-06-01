// ────────────────────────────────────────────────────────────
//  collections.ox  –  Deque, DefaultDict
// ────────────────────────────────────────────────────────────

class Deque<T> {
    data: List<T>;
}

pub fn deque_new<T>() -> Deque<T> {
    return Deque<T> { data: List<T>() };
}

pub fn deque_append<T>(dq: Deque<T>, val: T) {
    push(dq.data, val);
}

pub fn deque_appendleft<T>(dq: Deque<T>, val: T) {
    list_insert(dq.data, 0, val);
}

pub fn deque_pop<T>(dq: Deque<T>) -> T {
    return pop(dq.data);
}

pub fn deque_popleft<T>(dq: Deque<T>) -> T {
    return list_remove(dq.data, 0);
}

pub fn deque_len<T>(dq: Deque<T>) -> int {
    return len(dq.data);
}

// ── DefaultDict ────────────────────────────────────────────

class DefaultDict<K, V> {
    data: Map<K, V>;
    default_val: V;
}

pub fn default_dict_new<K, V>(default_val: V) -> DefaultDict<K, V> {
    return DefaultDict<K, V> { data: Map<K, V>(), default_val: default_val };
}

pub fn dd_get<K, V>(dd: DefaultDict<K, V>, key: K) -> V {
    if map_contains(dd.data, key) {
        return map_get(dd.data, key);
    }
    return dd.default_val;
}

pub fn dd_set<K, V>(dd: DefaultDict<K, V>, key: K, val: V) {
    map_set(dd.data, key, val);
}

pub fn dd_contains<K, V>(dd: DefaultDict<K, V>, key: K) -> bool {
    return map_contains(dd.data, key);
}
