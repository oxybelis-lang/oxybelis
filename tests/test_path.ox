// ── test_path.ox ──
// Tests: path module

import path

fn main() {
    // ── path_join ──
    print(path.path_join(["foo", "bar"]))
    print(path.path_join(["foo", "bar", "baz"]))
    print(path.path_join(["foo", "", "bar"]))
    print(path.path_join(["/", "usr", "bin"]))

    // ── path_split ──
    let sp1 = path.path_split("foo/bar")
    print(sp1)
    let sp2 = path.path_split("/foo/bar")
    print(sp2)
    let sp3 = path.path_split("foo//bar")
    print(sp3)

    // ── path_dirname ──
    print(path.path_dirname("foo/bar"))
    print(path.path_dirname("foo/bar/baz"))
    print(path.path_dirname("foo"))
    print(path.path_dirname("/foo"))

    // ── path_basename ──
    print(path.path_basename("foo/bar"))
    print(path.path_basename("foo/bar/baz"))
    print(path.path_basename("foo"))
    print(path.path_basename("/foo"))

    // ── path_stem ──
    print(path.path_stem("foo.txt"))
    print(path.path_stem("foo.tar.gz"))
    print(path.path_stem(".hidden"))
    print(path.path_stem("foo"))

    // ── path_ext ──
    print(path.path_ext("foo.txt"))
    print(path.path_ext("foo.tar.gz"))
    print(path.path_ext(".hidden"))
    print(path.path_ext("foo"))

    // ── path_normalize ──
    print(path.path_normalize("foo/./bar"))
    print(path.path_normalize("foo/../bar"))
    print(path.path_normalize("/foo/bar/../baz"))
    print(path.path_normalize("foo/bar/.."))
    print(path.path_normalize("."))
}
