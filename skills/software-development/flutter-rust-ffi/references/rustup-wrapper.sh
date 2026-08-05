#!/bin/bash
# rustup wrapper — for Arch Linux system Rust (no rustup installed)
# Handles basic cargokit queries. For real cross-compilation targets,
# install the real rustup: curl -sSf https://sh.rustup.rs | sh -s -- -y
#
# Place at ~/.local/bin/rustup and ensure ~/.local/bin is in PATH.

REAL_RUSTUP="$HOME/.cargo/bin/rustup"
if [ -x "$REAL_RUSTUP" ]; then
    # Real rustup exists — delegate everything
    exec "$REAL_RUSTUP" "$@"
fi

RUSTC_VERSION="1.95.0"
HOST_TARGET="x86_64-unknown-linux-gnu"

cmd="$1"
shift

case "$cmd" in
    toolchain)
        sub="$1"
        case "$sub" in
            list)    echo "stable-$HOST_TARGET (system)"; echo "stable (system)"; echo "$RUSTC_VERSION-$HOST_TARGET (system)" ;;
            install) exit 0 ;;
        esac
        ;;
    target)
        sub="$1"
        case "$sub" in
            list) echo "$HOST_TARGET (installed)"; echo "x86_64-unknown-linux-gnu (installed)"; echo "wasm32-unknown-unknown (installed)" ;;
            add)  exit 0 ;;
        esac
        ;;
    which)
        case "$1" in
            rustc) echo "/usr/bin/rustc" ;;
            cargo) echo "/usr/bin/cargo" ;;
        esac
        ;;
    show)   /usr/bin/rustc --version 2>/dev/null || echo "System Rust $RUSTC_VERSION" ;;
    default) echo "stable-$HOST_TARGET" ;;
    version|--version) echo "rustup wrapper v1 (system Rust $RUSTC_VERSION)" ;;
    *) exit 0 ;;
esac
