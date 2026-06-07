import collections

fn main() {
    // OrderedDict
    let od = collections.ordered_dict_new<str,int>()
    collections.od_set(od, str("x"), 1)
    collections.od_set(od, str("y"), 2)
    collections.od_set(od, str("z"), 3)
    print(collections.od_keys(od))
    print(collections.od_values(od))

    // Dict alias
    let d: Map<str,int> = collections.dict_new<str,int>()
    map_set(d, str("a"), 10)
    print(map_get(d, str("a")))

    // Counter
    let c = collections.counter_new<str>()
    let items: List<str> = ["a","b","a","c","b","a"]
    collections.counter_update(c, items)
    print(collections.counter_get(c, str("a")))
    let top = collections.counter_most_common(c, 2)
    print(top[0].first)
    print(top[0].second)

    // FrozenSet
    let nums: List<int> = [1,2,3,2,1]
    let fs = collections.frozenset_from_list(nums)
    print(collections.frozenset_contains(fs, 2))
    print(collections.frozenset_contains(fs, 99))
}
