// ── test_collections.ox ──
// Tests: List, Map, methods

fn dbl(x: int) -> int { return x * 2 }
fn is_even(x: int) -> bool { return x % 2 == 0 }
fn add(acc: int, x: int) -> int { return acc + x }
fn gt3(x: int) -> bool { return x > 3 }
fn lt10(x: int) -> bool { return x < 10 }
fn eq3(x: int) -> bool { return x == 3 }

fn main() {
    // ── List basics ──
    var v: List<int> = []
    push(v, 10)
    push(v, 20)
    push(v, 30)
    push(v, 40)
    print(v)
    print(len(v))
    
    let last = pop(v)
    print(last)
    print(v)
    
    list_insert(v, 1, 99)
    print(v)
    
    let removed = list_remove(v, 2)
    print(removed)
    print(v)
    
    print(contains(v, 20))
    print(contains(v, 999))
    
    // ── List methods ──
    var nums: List<int> = [1, 2, 3, 4, 5]
    print(nums)
    
    let doubled = nums.map(dbl)
    print(doubled)
    
    let evens = nums.filter(is_even)
    print(evens)
    
    let sum = nums.reduce(0, add)
    print(sum)
    
    let has_big = nums.any(gt3)
    print(has_big)
    
    let all_small = nums.all(lt10)
    print(all_small)
    
    let found = nums.find(eq3)
    print(found)
    
    print(nums.sum())
    print(nums.min())
    print(nums.max())
    
    // ── Map basics ──
    var m: Map<str, int> = Map<str, int>()
    let ka: str = "a"
    let kb: str = "b"
    let kc: str = "c"
    let kz: str = "z"
    map_set(m, ka, 1)
    map_set(m, kb, 2)
    map_set(m, kc, 3)
    print(map_contains(m, ka))
    print(map_contains(m, kz))
    print(map_get(m, kb))
    
    // ── for over list ──
    var total = 0
    for x in nums {
        total = total + x
    }
    print(total)
}
