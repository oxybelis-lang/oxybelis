#!/usr/bin/env bash
#
# Oxybelis installer – one-command setup for Linux / macOS.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/oxybelis-lang/oxybelis/main/install.sh | sh
#   ./install.sh
#   ./install.sh --version 0.3.0 --dir ~/.local/oxybelis
#
# Prerequisites:
#   Linux:   g++ (apt install build-essential)
#   macOS:   clang++ (xcode-select --install)
#

set -euo pipefail

# ── Config ────────────────────────────────────────────────────
REPO="oxybelis-lang/oxybelis"
VERSION=""
INSTALL_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)   VERSION="$2";    shift 2 ;;
        --dir)       INSTALL_DIR="$2"; shift 2 ;;
        --help|-h)   echo "Usage: install.sh [--version X] [--dir PATH]"; exit 0 ;;
        *)           echo "Unknown: $1"; exit 1 ;;
    esac
done

if [[ -z "$VERSION" ]]; then VERSION="0.3.0"; fi

# ── Platform ──────────────────────────────────────────────────
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64|amd64) BIN_ARCH="x86_64" ;;
    aarch64|arm64) BIN_ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
    linux)   TRIPLE="${BIN_ARCH}-unknown-linux-gnu";   CXX_REQ="g++" ;;
    darwin)  TRIPLE="${BIN_ARCH}-apple-darwin";         CXX_REQ="clang++ (Xcode CLT)" ;;
    *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

# ── Paths ─────────────────────────────────────────────────────
OX_HOME="${INSTALL_DIR:-"$HOME/.oxybelis"}"
BIN_DIR="$OX_HOME/bin"
mkdir -p "$BIN_DIR"

# ── Helpers ───────────────────────────────────────────────────
step() { printf "  → \033[36m%s\033[0m\n" "$*"; }
ok()   { printf "  ✓ \033[32m%s\033[0m\n" "$*"; }
warn() { printf "  ⚠ \033[33m%s\033[0m\n" "$*"; }

add_to_path() {
    local dir="$1"
    local profile="${2:-"$HOME/.profile"}"
    local line="export PATH=\"\$PATH:$dir\""
    if ! echo "$PATH" | tr ':' '\n' | grep -qxF "$dir"; then
        if ! grep -qxF "$line" "$profile" 2>/dev/null; then
            echo "" >> "$profile"
            echo "# Oxybelis" >> "$profile"
            echo "$line" >> "$profile"
            ok "Added to PATH in $profile"
        fi
        export PATH="$PATH:$dir"
    else
        ok "$dir already in PATH"
    fi
}

# ── Check prerequisites ───────────────────────────────────────
printf "\n  \033[32m╔══════════════════════════════════════════╗\033[0m\n"
printf "  \033[32m║          Oxybelis Installer              ║\033[0m\n"
printf "  \033[32m╚══════════════════════════════════════════╝\033[0m\n\n"

step "Platform: $OS ($BIN_ARCH)"
step "Version:  $VERSION"
step "Install:  $OX_HOME"

if ! command -v g++ &>/dev/null && ! command -v clang++ &>/dev/null; then
    warn "C++ compiler not found – Oxybelis needs it to compile programs."
    if [[ "$OS" == "linux" ]]; then
        echo "  Install: apt install build-essential  (or your distro's equivalent)"
    elif [[ "$OS" == "darwin" ]]; then
        echo "  Install: xcode-select --install"
    fi
fi

# ── Download ──────────────────────────────────────────────────
BASE="https://github.com/$REPO/releases/download/v$VERSION"
ARCHIVE="oxybelis-$TRIPLE.tar.gz"
URL="$BASE/$ARCHIVE"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

step "Downloading $URL …"
if command -v curl &>/dev/null; then
    curl -fsSL "$URL" -o "$TMPDIR/$ARCHIVE"
elif command -v wget &>/dev/null; then
    wget -q "$URL" -O "$TMPDIR/$ARCHIVE"
else
    echo "  Need curl or wget to download."; exit 1
fi

step "Extracting…"
tar xzf "$TMPDIR/$ARCHIVE" -C "$TMPDIR"
cp "$TMPDIR"/oxybelis* "$BIN_DIR/" 2>/dev/null || true
chmod +x "$BIN_DIR"/* 2>/dev/null || true

# Add to PATH
case "$SHELL" in
    *zsh) add_to_path "$BIN_DIR" "$HOME/.zshrc" ;;
    *bash) add_to_path "$BIN_DIR" "$HOME/.bashrc" ;;
    *)    add_to_path "$BIN_DIR" ;;
esac

# Verify
echo ""
if [[ -f "$BIN_DIR/oxybelis" ]]; then
    size="$(du -h "$BIN_DIR/oxybelis" | cut -f1)"
    ok "oxybelis — $size"
    printf "\n  \033[32m🎉 Oxybelis installed!\033[0m\n\n"
    echo '  Quick start:'
    echo '    echo '\''print("hello world")'\'' > hello.ox'
    echo '    oxybelis hello.ox'
    echo ""
    if [[ "$OS" == "linux" ]]; then
        echo '  Need g++?  apt install build-essential'
    elif [[ "$OS" == "darwin" ]]; then
        echo '  Need clang++?  xcode-select --install'
    fi
    echo "  Uninstall: rm -rf $OX_HOME"
else
    echo "  ✗ Installation failed: oxybelis not found"
    exit 1
fi
