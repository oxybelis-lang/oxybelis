import regex

fn main() {
    let text = "hello 42 world 99 end"

    print("match digits: ")
    print(str(regex.matches("\\d+", "123")))
    print("\n")

    print("search digits: ")
    print(str(regex.search("\\d+", text)))
    print("\n")

    print("no match: ")
    print(str(regex.matches("\\d+", "abc")))
    print("\n")

    let first = regex.find("\\d+", text)
    if first.is_some() {
        print("found: ")
        print(first.value)
        print("\n")
    }

    let all = regex.find_all("\\d+", text)
    print("all: ")
    print(str(all))
    print("\n")

    let replaced = regex.replace("\\d+", text, "X")
    print("replaced: ")
    print(replaced)
    print("\n")

    let parts = regex.split("\\s+", text)
    print("parts: ")
    print(str(parts))
    print("\n")
}
