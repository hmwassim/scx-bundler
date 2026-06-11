#!/bin/bash
set -euo pipefail

RELEASE="${1:-trixie}"
TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"
REPODIR="$TOPDIR/repo"
COMPONENT="main"

cd "$REPODIR"

if [ ! -d "pool" ]; then
  echo "No pool directory found. Run 'make build' first."
  exit 1
fi

echo "==> Scanning pool for packages..."

for arch in amd64; do
  dist_dir="dists/$RELEASE/$COMPONENT/binary-$arch"
  mkdir -p "$dist_dir"

  packages_gz="$dist_dir/Packages.gz"
  tmp_packages=$(mktemp)

  find pool -name "*_${arch}.deb" -type f | sort | while read -r deb; do
    deb_path="${deb#./}"
    size=$(stat -c%s "$deb")
    md5=$(md5sum "$deb" | cut -d' ' -f1)
    sha256=$(sha256sum "$deb" | cut -d' ' -f1)

    cat >> "$tmp_packages" <<-STANZA
Package: $(dpkg-deb --field "$deb" Package)
Version: $(dpkg-deb --field "$deb" Version)
Architecture: $(dpkg-deb --field "$deb" Architecture)
Maintainer: $(dpkg-deb --field "$deb" Maintainer)
Installed-Size: $(dpkg-deb --field "$deb" Installed-Size)
$(if dpkg-deb --field "$deb" Depends | grep -q .; then echo "Depends: $(dpkg-deb --field "$deb" Depends)"; fi)
$(if dpkg-deb --field "$deb" Recommends | grep -q .; then echo "Recommends: $(dpkg-deb --field "$deb" Recommends)"; fi)
Section: $(dpkg-deb --field "$deb" Section)
Priority: $(dpkg-deb --field "$deb" Priority)
Homepage: $(dpkg-deb --field "$deb" Homepage)
Description: $(dpkg-deb --field "$deb" Description)
Size: $size
MD5sum: $md5
SHA256: $sha256
Filename: $deb_path

STANZA
  done

  gzip -c "$tmp_packages" > "$packages_gz"
  rm -f "$tmp_packages"
  echo "  Wrote $packages_gz ($(zcat "$packages_gz" | grep -c '^Package:') packages)"
done

echo "==> Generating Release file..."
release_file="dists/$RELEASE/Release"
{
  echo "Origin: scx-bundler"
  echo "Label: sched_ext Debian packages"
  echo "Suite: $RELEASE"
  echo "Codename: $RELEASE"
  echo "Date: $(date -Ru)"
  echo "Architectures: amd64"
  echo "Components: $COMPONENT"
  echo "Description: Unofficial sched_ext Debian package repository"

  for arch in amd64; do
    dist_dir="dists/$RELEASE/$COMPONENT/binary-$arch"
    packages_gz="$dist_dir/Packages.gz"
    if [ -f "$packages_gz" ]; then
      size=$(stat -c%s "$packages_gz")
      sha256=$(sha256sum "$packages_gz" | cut -d' ' -f1)
      md5sum_val=$(md5sum "$packages_gz" | cut -d' ' -f1)
      echo " $md5sum_val $size $COMPONENT/binary-$arch/Packages.gz"
      echo " $sha256 $size $COMPONENT/binary-$arch/Packages.gz"
    fi
  done
} > "$release_file"

echo "==> Repository ready at $REPODIR"
