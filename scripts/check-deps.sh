#!/bin/bash
set -euo pipefail

MISSING=0

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "  MISSING: $1 ($2)"
    return 1
  fi
  return 0
}

echo "==> Checking required commands..."
check_cmd "git" "git package" || MISSING=$((MISSING+1))
check_cmd "dpkg-deb" "dpkg-dev package" || MISSING=$((MISSING+1))
check_cmd "gzip" "gzip package" || MISSING=$((MISSING+1))
check_cmd "sha256sum" "coreutils package" || MISSING=$((MISSING+1))
check_cmd "md5sum" "coreutils package" || MISSING=$((MISSING+1))
check_cmd "curl" "curl package" || MISSING=$((MISSING+1))
check_cmd "clang" "clang package (>= 16)" || MISSING=$((MISSING+1))

echo "==> Checking Rust toolchain..."
if command -v rustup &>/dev/null; then
  echo "  FOUND: rustup ($(rustup --version 2>/dev/null | head -1))"
elif [ -n "${RUSTUP_HOME:-}" ] && [ -x "$RUSTUP_HOME/bin/rustup" ]; then
  echo "  FOUND: rustup (sandboxed)"
else
  echo "  NOT FOUND: rustup will be bootstrapped by 'make setup-rust'"
fi

echo "==> Checking optional system libraries..."
check_lib() {
  if ! dpkg -s "$1" &>/dev/null 2>&1; then
    echo "  OPTIONAL: $1 (install if missing for compilation)"
  fi
}

check_lib "libbpf-dev"
check_lib "libelf-dev"
check_lib "libcap-dev"
check_lib "zlib1g-dev"
check_lib "libseccomp-dev"
check_lib "llvm"
check_lib "linux-libc-dev"
check_lib "bpftool"

echo ""
if [ "$MISSING" -gt 0 ]; then
  echo "==> $MISSING required deps missing. Install with:"
  echo "    sudo apt install git dpkg-dev gzip coreutils curl clang"
  exit 1
else
  echo "==> All system dependencies found."
fi
