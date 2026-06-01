#!/usr/bin/env bash
#
# Oxybelis toolchain installer – rustup-like for Unix (Linux / macOS).
#
# Usage:
#   curl -fsSL https://oxybelis.dev/install.sh | sh          # auto
#   ./install.sh                                              # local
#   ./install.sh --version 0.2.0 --dir ~/.local/oxybelis     # custom
#

set -euo pipefail

# ── Config ────────────────────────────────────────────────────
REPO="oxybelis-lang/oxybelis"
VERSION=""
INSTALL_DIR=""
LOCAL_BUILD=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)   VERSION="$2";    shift 2 ;;
        --dir)       INSTALL_DIR="$2"; shift 2 ;;
        --local|-l)  LOCAL_BUILD=1;   shift ;;
        --help|-h)   echo "Usage: install.sh [--version X] [--dir PATH] [--local]"; exit 0 ;;
        *)           echo "Unknown: $1"; exit 1 ;;
    esac
done

# Detect repo root for local builds
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$VERSION" && "$LOCAL_BUILD" -eq 0 ]]; then
    VERSION="0.3.0"
fi

# ── Platform detection ────────────────────────────────────────
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64|amd64) BIN_ARCH="x86_64" ;;
    aarch64|arm64) BIN_ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
    linux)   TRIPLE="${BIN_ARCH}-unknown-linux-gnu" ;;
    darwin)  TRIPLE="${BIN_ARCH}-apple-darwin" ;;
    msys*|cygwin*) TRIPLE="${BIN_ARCH}-pc-windows-msvc" ;;
    *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

# ── Install paths ─────────────────────────────────────────────
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
        # Add to shell profile for permanent effect
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

# ── Install ───────────────────────────────────────────────────
echo ""
printf "  \033[32m╔══════════════════════════════════════════╗\033[0m\n"
printf "  \033[32m║      Oxybelis Toolchain Installer        ║\033[0m\n"
printf "  \033[32m╚══════════════════════════════════════════╝\033[0m\n"
echo ""
step "Platform: $OS ($BIN_ARCH)"
step "Version:  ${VERSION:-local}"
step "Install:  $OX_HOME"

# Check existing
if [[ -f "$BIN_DIR/oxybelis" ]]; then
    warn "Oxybelis already installed at $BIN_DIR"
    read -rp "  Overwrite? [y/N] " reply
    [[ "$reply" =~ ^[yY] ]] || { echo "  Aborted."; exit 0; }
fi

if [[ "$LOCAL_BUILD" -eq 1 ]]; then
    step "Using local build…"
    RELEASE_DIR="$SCRIPT_DIR/dist/release"
    for bin in oxybelis ox-fmt ox-lsp; do
        src="$RELEASE_DIR/$bin"
        [[ -f "$src" ]] && { cp "$src" "$BIN_DIR/"; chmod +x "$BIN_DIR/$bin"; ok "Copied $bin"; } \
                       || { src="$RELEASE_DIR/$bin.exe"; [[ -f "$src" ]] && { cp "$src" "$BIN_DIR/"; chmod +x "$BIN_DIR/$bin"; ok "Copied $bin"; } || warn "$bin not found in $RELEASE_DIR"; }
    done
else
    # Download from GitHub
    BASE="https://github.com/$REPO/releases/download/v$VERSION"
    ARCHIVE="oxybelis-$TRIPLE.tar.gz"
    URL="$BASE/$ARCHIVE"
    TMPDIR="$(mktemp -d)"

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
    rm -rf "$TMPDIR"
fi

# Add to PATH
case "$SHELL" in
    *zsh) add_to_path "$BIN_DIR" "$HOME/.zshrc" ;;
    *bash) add_to_path "$BIN_DIR" "$HOME/.bashrc" ;;
    *)    add_to_path "$BIN_DIR" ;;
esac

# Verify
echo ""
step "Verifying installation…"
for tool in oxybelis ox-fmt ox-lsp; do
    path="$BIN_DIR/$tool"
    if [[ -f "$path" ]]; then
        size="$(du -h "$path" | cut -f1)"
        ok "$tool — $size"
    else
        warn "$tool not found"
    fi
done

echo ""
printf "  \033[32m🎉 Oxybelis installed successfully!\033[0m\n"
echo ""
echo "  You can now run:"
echo "    oxybelis --help"
echo "    ox-fmt    --help"
echo "    ox-lsp    --help"
echo ""
printf "  \033[33m  To uninstall, remove $OX_HOME\033[0m\n"
echo ""
