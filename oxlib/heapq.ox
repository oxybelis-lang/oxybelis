// ────────────────────────────────────────────────────────────
//  heapq.ox  –  Heap queue algorithm
//  Mirrors the Python `heapq` module. Heaps are plain
//  List<int> (a min-heap: heap[0] is the smallest item).
// ────────────────────────────────────────────────────────────

pub fn heappush(heap: List<int>, item: int) {
    push(heap, item)
    var i: int = len(heap) - 1
    while i > 0 {
        let parent = (i - 1) / 2
        if heap[i] < heap[parent] {
            let t = heap[i]
            heap[i] = heap[parent]
            heap[parent] = t
            i = parent
        } else {
            i = 0
        }
    }
}

pub fn heappop(heap: List<int>) -> int {
    let n: int = len(heap)
    if n == 0 { return 0 }
    let top = heap[0]
    heap[0] = heap[n - 1]
    pop(heap)
    var i = 0
    while true {
        let left = 2 * i + 1
        if left >= len(heap) { break }
        let right = left + 1
        var smallest = left
        if right < len(heap) and heap[right] < heap[left] {
            smallest = right
        }
        if heap[smallest] < heap[i] {
            let t = heap[i]
            heap[i] = heap[smallest]
            heap[smallest] = t
            i = smallest
        } else {
            break
        }
    }
    return top
}

pub fn heapify(heap: List<int>) {
    var i: int = len(heap) / 2
    while i >= 0 {
        var j = i
        while true {
            let left = 2 * j + 1
            if left >= len(heap) { break }
            let right = left + 1
            var smallest = left
            if right < len(heap) and heap[right] < heap[left] {
                smallest = right
            }
            if heap[smallest] < heap[j] {
                let t = heap[j]
                heap[j] = heap[smallest]
                heap[smallest] = t
                j = smallest
            } else {
                break
            }
        }
        i = i - 1
    }
}

pub fn heappushpop(heap: List<int>, item: int) -> int {
    if len(heap) > 0 and heap[0] < item {
        let t = heap[0]
        heap[0] = item
        sift_down(heap, 0)
        return t
    }
    return item
}

pub fn heapreplace(heap: List<int>, item: int) -> int {
    let t = heap[0]
    heap[0] = item
    sift_down(heap, 0)
    return t
}

pub fn nsmallest(n: int, iterable: List<int>) -> List<int> {
    var s = sorted(iterable)
    var result: List<int> = []
    var i = 0
    while i < n and i < len(s) {
        push(result, s[i])
        i = i + 1
    }
    return result
}

pub fn nlargest(n: int, iterable: List<int>) -> List<int> {
    var s = sorted(iterable)
    var result: List<int> = []
    var i = 0
    while i < n and i < len(s) {
        push(result, s[len(s) - 1 - i])
        i = i + 1
    }
    return result
}

fn sift_down(heap: List<int>, start: int) {
    var i = start
    while true {
        let left = 2 * i + 1
        if left >= len(heap) { break }
        let right = left + 1
        var smallest = left
        if right < len(heap) and heap[right] < heap[left] {
            smallest = right
        }
        if heap[smallest] < heap[i] {
            let t = heap[i]
            heap[i] = heap[smallest]
            heap[smallest] = t
            i = smallest
        } else {
            break
        }
    }
}
