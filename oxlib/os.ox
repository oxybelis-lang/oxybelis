// ────────────────────────────────────────────────────────────
//  os.ox  –  Operating system interfaces
//  Mirrors the Python `os` module (subset).
// ────────────────────────────────────────────────────────────

pub let sep: str = "/"
pub let pathsep: str = ":"
pub let linesep: str = "\n"
pub let name: str = _ox_platform()

pub fn getcwd() -> str {
    return fs_cwd()
}

pub fn chdir(path: str) -> bool {
    return _ox_chdir(path)
}

pub fn listdir(path: str) -> List<str> {
    return fs_list_dir(path)
}

pub fn mkdir(path: str) {
    fs_mkdir(path)
}

pub fn remove(path: str) {
    fs_remove(path)
}

pub fn rename(old_path: str, new_path: str) {
    fs_rename(old_path, new_path)
}

pub fn getenv(key: str) -> str {
    return _ox_getenv(key)
}

pub fn setenv(key: str, value: str) -> bool {
    return _ox_setenv(key, value)
}

pub fn system(command: str) -> int {
    _ox_popen_out(command)
    return 0
}

pub fn walk(root: str) -> List<str> {
    return _ox_walk(root)
}

pub fn is_file(path: str) -> bool {
    return fs_is_file(path)
}

pub fn is_dir(path: str) -> bool {
    return fs_is_dir(path)
}

pub fn exists(path: str) -> bool {
    return fs_exists(path)
}
