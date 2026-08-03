import math
import numpy
import time
import heapq

// Generic reduce function (testing generics)
pub fn custom_reduce<T, F>(f: F, init: T, data: List<T>) -> T {
    var acc = init
    var i = 0
    while i < len(data) {
        acc = f(acc, data[i])
        i = i + 1
    }
    return acc
}

// Helper function for custom_reduce
fn add_ints(a: int, b: int) -> int {
    return a + b
}

// Class with constructor and method (testing class implementation)
class Point {
    pub x: float
    pub y: float

    pub fn create(x: float, y: float) -> Point {
        return Point { x: x, y: y }
    }

    pub fn dist(self) -> float {
        return math.sqrt(self.x * self.x + self.y * self.y)
    }
}

// Container mutation demonstration
pub fn mutate_list(list: List<int>) {
    list[0] = list[0] * 2  // In-place mutation
    print("Mutated list: " + str(list))
}

// Demonstrates Result type for error handling
pub fn potentially_fail() -> Result<int, str> {
    if false { // Simulate error condition
        return Err("simulated error")
    } else {
        return Ok(42)
    }
}

// Heap operations (test heapq functionality)
pub fn heap_demo() {
    var heap: List<int> = [5, 1, 8, 3]
    heapq.heapify(heap)
    print("Heapify result: " + str(heap))

    let smallest = heapq.heappop(heap)
    print("Smallest: " + str(smallest))

    heapq.heappush(heap, 0)
    print("After push: " + str(heap))
}

// Timing demonstration
pub fn timing_demo() {
    let start = time.perf_counter()
    // Sleep for 1 second to test timing
    time.sleep(1.0)
    let end = time.perf_counter()
    print("Elapsed time: " + str(end - start) + " seconds")
}

// String formatting example
pub fn format_string(prefix: str, suffix: str) -> str {
    return prefix + "A" + suffix + "B"
}

// Main function to execute all tests
fn main() {
    print("Oxybelis Compiler Demo v1.0\n")

    // Mathematical operations
    print("\nMath Functions:")
    let sqrt_val = math.sqrt(25.0)
    let pow_val = math.pow(2.0, 5.0)
    let sin_val = math.sin(math.PI / 2.0)
    print("sqrt(25) = " + str(sqrt_val) + " | 2^5 = " + str(pow_val) + " | sin(pi/2) = " + str(sin_val))

    // Numpy array operations
    print("\nNumpy Arrays:")
    let np_arr: List<float> = numpy.arange(0.0, 3.0, 1.0)
    print("Range array: " + str(np_arr))
    let np_sum = numpy.sum(np_arr)
    print("Sum of array: " + str(np_sum))

    // Matrix operations with numpy
    let np_mat: List<List<float>> = numpy.eye(3)
    print("\nIdentity matrix: " + str(np_mat))
    let np_prod = numpy.matmul(np_mat, np_mat)
    print("Matrix product: " + str(np_prod))

    // General demo of container mutation
    print("\nContainer Mutation (List):")
    let mutable_list: List<int> = [10, 20, 30]
    mutate_list(mutable_list)
    print("After mutation: " + str(mutable_list))

    // Heap demonstration
    print("\nHeap Operations:")
    heap_demo()

    // Error handling
    print("\nError Handling:")
    let result = potentially_fail()
    print("potentially_fail() = " + str(result))

    // Generics demonstration
    print("\nGenerics Demo:")
    let gen_list: List<int> = [1, 2, 3, 4, 5]
    let generic_result = custom_reduce(add_ints, 0, gen_list)
    print("Custom reduce sum: " + str(generic_result))

    // Timing test
    print("\nTiming Test:")
    timing_demo()

    // String formatting
    print("\nString Formatting:")
    let formatted = format_string("Start: ", "End: ")
    print("Formatted string: " + formatted)

    // Exit normally
    print("\nProgram executed successfully. Exiting...")
    exit(0)
}
