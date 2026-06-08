// ────────────────────────────────────────────────────────────
//  examples/functional.ox  –  map, filter, reduce, and friends
// ────────────────────────────────────────────────────────────

fn dbl(x: int) -> int {
    return x * 2;
}

fn is_even(x: int) -> bool {
    return x % 2 == 0;
}

fn is_odd(x: int) -> bool {
    return x % 2 == 1;
}

fn add(a: int, b: int) -> int {
    return a + b;
}

fn print_item(x: int) {
    print(x);
}

fn lt4(x: int) -> bool {
    return x < 4;
}

fn gt8(x: int) -> bool { return x > 8; }

fn main() {
    print("═══ Functional Chaining Demo ═══");
    print("");

    var numbers: List<int> = [1, 2, 3, 4, 5, 6];

    print("numbers.map(dbl):");
    let dbld = numbers.map(dbl);
    print(dbld);

    print("numbers.filter(is_even):");
    let evens = numbers.filter(is_even);
    print(evens);

    print("numbers.reduce(0, add):");
    let sum = numbers.reduce(0, add);
    print(sum);

    print("numbers.any(is_even):");
    print(numbers.any(is_even));

    print("numbers.all(is_even):");
    print(numbers.all(is_even));

    print("numbers.find(is_even):");
    print(numbers.find(is_even));

    print("numbers.sum():");
    print(numbers.sum());

    print("numbers.min():");
    print(numbers.min());

    print("numbers.max():");
    print(numbers.max());

    print("numbers.for_each(print_item):");
    numbers.for_each(print_item);
    print("");

    print("Chained: numbers.filter(is_even).map(dbl):");
    let chained = numbers.filter(is_even).map(dbl);
    print(chained);

	print("Chained: numbers.filter(is_odd).map(dbl).reduce(0, add):");
	let pipeline = numbers.filter(is_odd).map(dbl).reduce(0, add);
	print(pipeline);
	print("");

	// Sorted examples
    print("numbers.sorted():")
    let sorted_asc = numbers.sorted()
    print(sorted_asc)

    print("numbers.map(dbl).sorted():")
    let mapped_sorted = numbers.map(dbl).sorted()
    print(mapped_sorted)

    print("numbers.filter(is_even).sorted():")
    let filtered_sorted = numbers.filter(is_even).sorted()
    print(filtered_sorted)

    print("Chained: numbers.map(dbl).filter(gt8).sorted():")
    let chain = numbers.map(dbl).filter(gt8).sorted()
    print(chain)

	print("");
	print("═══ Done ═══");
}
