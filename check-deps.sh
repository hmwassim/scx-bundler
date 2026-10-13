#!/bin/bash
# Fail early, listing every missing build dependency in one apt command.
set -euo pipefail

PACKAGES=(git curl clang llvm pkg-config dpkg-dev protobuf-compiler
          libbpf-dev libelf-dev libseccomp-dev zlib1g-dev)

missing=()
for pkg in "${PACKAGES[@]}"; do
    [ "$(dpkg-query -W -f '${db:Status-Status}' "$pkg" 2>/dev/null)" = installed ] || missing+=("$pkg")
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing build dependencies. Install them with:" >&2
    echo "  sudo apt install ${missing[*]}" >&2
    exit 1
fi
