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
	print("numbers.sorted():");
	let sorted_asc = numbers.sorted();
	print(sorted_asc); // [1, 2, 3, 4, 5, 6]

	print("numbers.sorted(reverse=true):");
	let sorted_desc = numbers.sorted(reverse=true);
	print(sorted_desc); // [6, 5, 4, 3, 2, 1]

	// Chained: filter -> map -> sorted
	print("Chained: numbers.filter(is_odd).map(dbl).sorted(reverse=true):");
	let odd_doubled_sorted = numbers.filter(is_odd).map(dbl).sorted(reverse=true);
	print(odd_doubled_sorted); // [12, 8, 4] (3*2=6,5*2=10, wait: odds are 1,3,5 -> doubled 2,6,10 sorted desc = [10,6,2])

	// Chained: map -> filter -> sorted
	print("Chained: numbers.map(dbl).filter(x => x > 8).sorted():");
	let mapped_filtered_sorted = numbers.map(dbl).filter(fn(x) { return x > 8; }).sorted();
	print(mapped_filtered_sorted); // [10, 8] (2*2=4>8?no,3*2=6>8?no,4*2=8 not>8,5*2=10>8yes,6*2=12>8yes -> sorted asc = [10,12])

	print("");
	print("═══ Done ═══");
}
