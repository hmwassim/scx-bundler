#!/bin/bash
# Write APT metadata for the .debs in repo/pool.
#   mkrepo.sh [SUITE]
set -euo pipefail

SUITE=${1:-trixie}
cd "$(dirname "$0")/repo"

dist=dists/$SUITE
mkdir -p "$dist/main/binary-amd64"
dpkg-scanpackages --arch amd64 pool > "$dist/main/binary-amd64/Packages"
gzip -9kf "$dist/main/binary-amd64/Packages"

{
    echo "Origin: scx-bundler"
    echo "Label: scx-bundler"
    echo "Suite: $SUITE"
    echo "Codename: $SUITE"
    echo "Date: $(date -Ru)"
    echo "Architectures: amd64"
    echo "Components: main"
    echo "SHA256:"
    for f in main/binary-amd64/Packages main/binary-amd64/Packages.gz; do
        printf ' %s %s %s\n' "$(sha256sum < "$dist/$f" | cut -d' ' -f1)" "$(stat -c%s "$dist/$f")" "$f"
    done
} > "$dist/Release"

echo "==> repo/$dist ready"
