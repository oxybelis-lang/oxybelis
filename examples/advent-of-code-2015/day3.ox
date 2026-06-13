class Santa {
    x: int
    y: int

    fn move(self, direction: str) -> void {
        if direction == "<" {
            self.x = self.x - 1
        } elif direction == ">" {
            self.x = self.x + 1
        } elif direction == "^" {
            self.y = self.y - 1
        } elif direction == "v" {
            self.y = self.y + 1
        }
    }
}

fn main() -> void {
    let directions: str = read_lines("day3.txt")[0]

    var visited1: list<str> = ["0,0"]
    var santa = Santa(0, 0)
    for i in 0..len(directions) {
        santa.move(str_get(directions, i))
        let k = str(santa.x) + "," + str(santa.y)
        if not contains(visited1, k) {
            push(visited1, k)
        }
    }
    print("Part 1: " + str(len(visited1)))

    var visited2: list<str> = ["0,0"]
    var real_santa = Santa(0, 0)
    var robo_santa = Santa(0, 0)
    for pair in batched(directions, 2) {
        real_santa.move(pair[0])
        robo_santa.move(pair[1])
        let k1 = str(real_santa.x) + "," + str(real_santa.y)
        if not contains(visited2, k1) { push(visited2, k1) }
        let k2 = str(robo_santa.x) + "," + str(robo_santa.y)
        if not contains(visited2, k2) { push(visited2, k2) }
    }
    print("Part 2: " + str(len(visited2)))
}
