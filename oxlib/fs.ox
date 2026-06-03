// ────────────────────────────────────────────────────────────
//  fs.ox  –  Filesystem operations
// ────────────────────────────────────────────────────────────

pub fn exists(path: str) -> bool {
    return fs_exists(path);
}

pub fn is_file(path: str) -> bool {
    return fs_is_file(path);
}

pub fn is_dir(path: str) -> bool {
    return fs_is_dir(path);
}

pub fn mkdir(path: str) {
    fs_mkdir(path);
}

pub fn list_dir(path: str) -> List<str> {
    return fs_list_dir(path);
}

pub fn remove(path: str) {
    fs_remove(path);
}

pub fn rename(old_path: str, new_path: str) {
    fs_rename(old_path, new_path);
}

pub fn copy(from: str, to: str) {
    fs_copy(from, to);
}

pub fn cwd() -> str {
    return fs_cwd();
}
