// ── test_fs.ox ──
// Tests: filesystem module

import fs

fn is_hello(s: str) -> bool {
    return str_contains(s, "hello") or str_contains(s, "world")
}

fn println(s: str) {
    print(s)
}

fn main() {
    // ── cwd ──
    let d = fs.cwd()
    if fs.exists(d) { print("cwd_ok") }

    // ── exists / is_file / is_dir on cwd ──
    print(fs.is_dir(d))
    print(fs.is_file(d))

    // ── mkdir + exists + is_dir ──
    let test_dir = d + "/_ox_test_dir"
    fs.mkdir(test_dir)
    print(fs.exists(test_dir))
    print(fs.is_dir(test_dir))
    print(fs.is_file(test_dir))

    // ── list_dir should work ──
    let entries = fs.list_dir(d)
    if len(entries) > 0 { print("listed") }

    // ── write + exists + is_file + read ──
    let fpath = test_dir + "/test.txt"
    write_file(fpath, "hello fs!")
    print(fs.exists(fpath))
    print(fs.is_file(fpath))
    print(read_file(fpath))

    // ── copy + exists ──
    let fpath2 = test_dir + "/test_copy.txt"
    fs.copy(fpath, fpath2)
    print(fs.exists(fpath2))
    print(read_file(fpath2))

    // ── rename + exists ──
    let fpath3 = test_dir + "/test_renamed.txt"
    fs.rename(fpath2, fpath3)
    print(fs.exists(fpath2))
    print(fs.exists(fpath3))
    print(read_file(fpath3))

    // ── read_lines + chaining ──
    let lines_file = test_dir + "/lines.txt"
    write_file(lines_file, "hello world\nfoo bar\nhello again\nbaz")
    let all_lines = read_lines(lines_file)
    print(len(all_lines))
    print(all_lines[0])
    print(all_lines[1])
    print(all_lines[2])
    print(all_lines[3])
    all_lines.filter(is_hello).for_each(println)

    // ── remove ──
    fs.remove(fpath)
    fs.remove(fpath3)
    fs.remove(lines_file)
    print(fs.exists(fpath))
    print(fs.exists(fpath3))
    print(fs.exists(lines_file))
    fs.remove(test_dir)
    print(fs.exists(test_dir))
}
