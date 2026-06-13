class PresentBox {
    length: int
    width: int
    height: int
    
    fn wrapping_paper_needed(self) -> int {
        let side_areas: List<int> = [
            self.length * self.width,
            self.width * self.height,
            self.height * self.length,
        ]
        let box_surface_area = side_areas.map(|x| x * 2).sum()
        let slack = side_areas.min()
        return box_surface_area + slack
    }

    fn ribbon_length_needed(self) -> int {
        let dims = sorted((self.length, self.width, self.height))
        let smallest_perimeter = (dims[0] + dims[1]) * 2
        let box_volume = self.length * self.width * self.height
        return smallest_perimeter + box_volume
    }
}

fn main() -> void {
    var boxes: list<PresentBox> = []
    for line in read_lines("day2.txt") {
        // let dims: List<str> = str_split(line, "x")
        let dims = str_split(line, "x").map(to_int)
        push(boxes, PresentBox(dims[0], dims[1], dims[2]))
    }
    
    print(boxes.map(PresentBox.wrapping_paper_needed).sum())
    print(boxes.map(PresentBox.ribbon_length_needed).sum())
}
