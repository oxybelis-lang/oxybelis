fn main() {
    let data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]
    let arr = _ox_to_ndarray(data)
    print(arr[0])
    print(arr[4])
    print(arr[8])
    print(arr[0:3:1])
    print(arr[::2])
    print("done")
}
