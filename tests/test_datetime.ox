import datetime

fn main() {
    let now = datetime.now()
    print("now: ")
    print(now)
    print("\n")

    print("year: ")
    print(str(datetime.year(now)))
    print("\n")

    print("month: ")
    print(str(datetime.month(now)))
    print("\n")

    let formatted = datetime.format(now, "%Y-%m-%d")
    print("formatted: ")
    print(formatted)
    print("\n")

    let parsed = datetime.parse("2024-01-15", "%Y-%m-%d")
    print("parsed: ")
    print(parsed)
    print("\n")

    print("parsed year: ")
    print(str(datetime.year(parsed)))
    print("\n")
}
