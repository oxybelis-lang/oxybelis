"""
Build Oxybelis toolchain into standalone native executables via Nuitka.

Output: dist/release/{oxybelis,ox-fmt,ox-lsp}.exe
"""

import os
import shutil
import subprocess
import sys

VERSION = '0.3.3'

SCRIPTS = [
    ('oxybelis', 'oxybelis.py'),
    ('ox-fmt',    'ox_fmt.py'),
    ('ox-lsp',    'ox_lsp.py'),
]

OUT_DIR = os.path.join('dist', 'release')


def build():
    os.makedirs(OUT_DIR, exist_ok=True)

    for name, script in SCRIPTS:
        print(f"\n-- Building {name} --")
        subprocess.run([
            sys.executable, '-m', 'nuitka',
            '--onefile',
            '--assume-yes-for-downloads',
            '--include-windows-runtime-dlls=no',
            '--file-version=' + VERSION,
            '--product-name=' + name,
            '--output-dir=' + OUT_DIR,
            script,
        ], check=True)

        src = os.path.join(OUT_DIR, script.replace('.py', '.exe'))
        dst = os.path.join(OUT_DIR, name + '.exe')
        if src != dst and os.path.exists(src):
            os.replace(src, dst)

    # Clean up build artifacts
    for entry in os.listdir(OUT_DIR):
        path = os.path.join(OUT_DIR, entry)
        if os.path.isdir(path):
            shutil.rmtree(path)

    # Bundle NumCpp headers alongside the exes
    numcpp_src = os.path.join('NumCpp', 'include')
    numcpp_dst = os.path.join(OUT_DIR, 'NumCpp', 'include')
    if os.path.isdir(numcpp_src):
        if os.path.isdir(numcpp_dst):
            shutil.rmtree(numcpp_dst)
        shutil.copytree(numcpp_src, numcpp_dst)
        print(f"\n-- Bundled NumCpp headers ({numcpp_dst}) --")

    print("\n-- Done --")
    for entry in sorted(os.listdir(OUT_DIR)):
        size = os.path.getsize(os.path.join(OUT_DIR, entry))
        print(f"  {entry:20s} {size // 1024:>6} KB")


if __name__ == '__main__':
    build()
