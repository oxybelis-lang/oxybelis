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

// ── Additional collections: Dict, OrderedDict, Counter, FrozenSet, Pair ──

// Simple Pair<T,U> for returning items
class Pair<A, B> {
    first: A;
    second: B;
}

// Dict alias / constructor
pub fn dict_new<K, V>() -> Map<K, V> {
    return Map<K, V>()
}

// OrderedDict: preserves insertion order of keys
class OrderedDict<K, V> {
    keys: List<K>;
    data: Map<K, V>;
}

pub fn ordered_dict_new<K, V>() -> OrderedDict<K, V> {
    return OrderedDict<K, V> { keys: List<K>(), data: Map<K, V>() };
}

pub fn od_set<K, V>(od: OrderedDict<K, V>, key: K, val: V) {
    if not map_contains(od.data, key) {
        push(od.keys, key)
    }
    map_set(od.data, key, val)
}

pub fn od_get<K, V>(od: OrderedDict<K, V>, key: K) -> V {
    return map_get(od.data, key)
}

pub fn od_contains<K, V>(od: OrderedDict<K, V>, key: K) -> bool {
    return map_contains(od.data, key)
}

pub fn od_keys<K, V>(od: OrderedDict<K, V>) -> List<K> {
    return od.keys
}

pub fn od_values<K, V>(od: OrderedDict<K, V>) -> List<V> {
    let r: List<V> = List<V>()
    var i: int = 0
    while i < len(od.keys) {
        let k = od.keys[i]
        push(r, map_get(od.data, k))
        i = i + 1
    }
    return r
}

pub fn od_items<K, V>(od: OrderedDict<K, V>) -> List<Pair<K, V>> {
    let r: List<Pair<K, V>> = List<Pair<K, V>>()
    var i: int = 0
    while i < len(od.keys) {
        let k = od.keys[i]
        let p: Pair<K, V> = Pair<K, V> { first: k, second: map_get(od.data, k) }
        push(r, p)
        i = i + 1
    }
    return r
}

pub fn od_len<K, V>(od: OrderedDict<K, V>) -> int {
    return len(od.keys)
}

// Counter (multiset) with insertion-order keys tracking
class Counter<T> {
    data: Map<T, int>;
    keys: List<T>;
}

pub fn counter_new<T>() -> Counter<T> {
    return Counter<T> { data: Map<T, int>(), keys: List<T>() }
}

pub fn counter_update<T>(c: Counter<T>, items: List<T>) {
    var i: int = 0
    while i < len(items) {
        let x = items[i]
        if map_contains(c.data, x) {
            let cnt = map_get(c.data, x)
            map_set(c.data, x, cnt + 1)
        } else {
            map_set(c.data, x, 1)
            push(c.keys, x)
        }
        i = i + 1
    }
}

pub fn counter_get<T>(c: Counter<T>, k: T) -> int {
    if map_contains(c.data, k) { return map_get(c.data, k) }
    return 0
}

pub fn counter_most_common<T>(c: Counter<T>, n: int) -> List<Pair<T, int>> {
    // build list of pairs
    let lst: List<Pair<T, int>> = List<Pair<T, int>>()
    var i: int = 0
    while i < len(c.keys) {
        let k = c.keys[i]
        let p: Pair<T, int> = Pair<T, int> { first: k, second: map_get(c.data, k) }
        push(lst, p)
        i = i + 1
    }
    // simple selection sort by second desc
    var a: int = 0
    while a < len(lst) {
        var m: int = a
        var b: int = a + 1
        while b < len(lst) {
            if lst[b].second > lst[m].second { m = b }
            b = b + 1
        }
        if m != a {
            let tmp = lst[a]
            lst[a] = lst[m]
            lst[m] = tmp
        }
        a = a + 1
    }
    if n <= 0 or n >= len(lst) { return lst }
    // return first n
    let res: List<Pair<T, int>> = List<Pair<T, int>>()
    var j: int = 0
    while j < n {
        push(res, lst[j])
        j = j + 1
    }
    return res
}

// FrozenSet (immutable wrapper)
class FrozenSet<T> {
    data: Set<T>;
}

pub fn frozenset_from_list<T>(items: List<T>) -> FrozenSet<T> {
    let s: Set<T> = Set<T>()
    var i: int = 0
    while i < len(items) { set_add(s, items[i]); i = i + 1 }
    return FrozenSet<T> { data: s }
}

pub fn frozenset_union<T>(a: FrozenSet<T>, b: FrozenSet<T>) -> FrozenSet<T> {
    let r = set_union(a.data, b.data)
    return FrozenSet<T> { data: r }
}

pub fn frozenset_contains<T>(f: FrozenSet<T>, x: T) -> bool {
    return set_contains(f.data, x)
}
