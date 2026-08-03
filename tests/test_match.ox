fn main() {
    var x = 3
    match x {
        1 => { print("one") }
        2 => { print("two") }
        3 => { print("three") }
        _ => { print("other") }
    }
    match "hello" {
        "hi" => { print("greeting") }
        "hello" => { print("world") }
        _ => { print("unknown") }
    }
    for i in 0..5 {
        match i {
            0..3 => { print("small: " + str(i)) }
            3..5 => { print("medium: " + str(i)) }
            _ => { print("big: " + str(i)) }
        }
    }
}