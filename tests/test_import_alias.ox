import math as m
import heapq as hq

fn main() -> void {
    print("sqrt(16) = " + str(m.sqrt(16.0)))
    print("PI = " + str(m.PI))
    
    let lst: List<int> = [5, 1, 8, 3]
    hq.heapify(lst)
    print("heapify = " + str(lst))
    
    let smallest = hq.heappop(lst)
    print("pop = " + str(smallest))
    print("after = " + str(lst))
    
    hq.heappush(lst, 0)
    print("push = " + str(lst))
}