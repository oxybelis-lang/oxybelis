// ────────────────────────────────────────────────────────────
//  examples/itertools.ox  –  combinations, permutations, etc.
// ────────────────────────────────────────────────────────────

fn lt4(x: int) -> bool {
    return x < 4;
}

fn main() {
    print("═══ Iterator Toolkit ═══");
    print("");

    var items: List<int> = [1, 2, 3, 4, 5];
    print("items =");
    print(items);
    print("");

    print("items.combinations(2):");
    print(items.combinations(2));

    print("items.permutations(2):");
    print(items.permutations(2));
    print("");

    print("items.chunked(2):");
    print(items.chunked(2));
    print("items.chunked(3):");
    print(items.chunked(3));
    print("");

    print("items.windowed(3):");
    print(items.windowed(3));
    print("items.pairwise():");
    print(items.pairwise());
    print("");

    print("items.reversed():");
    print(items.reversed());

    print("items.cycle(3):");
    print(items.cycle(3));
    print("");

    print("items.take_while(lt4):");
    print(items.take_while(lt4));

    print("items.drop_while(lt4):");
    print(items.drop_while(lt4));
    print("");

    print("═══ Done ═══");
}
