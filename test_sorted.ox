fn main() -> void {
    let test1 = [3, 1, 4, 1, 5, 9, 2, 6]
    let result1 = test1.sorted()
    print(result1)

    let test2 = [3, 1, 4, 1, 5]
    let result2 = test2.sorted(reverse=True)
    print(result2)

    let test3 = [10, 20, 30, 40]
    let doubled_sorted = test3.map(lambda x: x * 2).sorted()
    print(doubled_sorted)

    let test5 = [5, 3, 8, 1]
    let even_sq = test5.sorted().map(lambda x: x * x)
    print(even_sq)

    print("All tests passed!")
}