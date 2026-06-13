fn main() {
    let s = "{\"name\": \"Alice\", \"age\": 30, \"scores\": [95.5, 87.0], \"active\": true, \"data\": null}"
    let v = json_parse(s)
    assert(json_is_dict(v))
    print(json_serialize(v))
    print(json_pretty(v, "  "))
    let name = json_get(v, "name")
    if name.is_some() {
        print("name: " + json_as_str(name.value))
    }
    let scores = json_get(v, "scores")
    if scores.is_some() {
        let arr = json_as_list(scores.value)
        print("score 0: " + str(json_as_float(arr[0])))
    }
    print("size: " + str(json_size(v)))
    print("has age: " + str(json_contains(v, "age")))
    print("keys: " + str(json_keys(v)))
    let o = json_object()
    json_set(o, "hello", json_str("world"))
    json_set(o, "count", json_int(42))
    print(json_pretty(o, "  "))
}
