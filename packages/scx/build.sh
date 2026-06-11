#!/bin/bash
set -euo pipefail

UPSTREAM_URL="https://github.com/sched-ext/scx"
PKGDIR="$(cd "$(dirname "$0")" && pwd)"
TOPDIR="$(cd "$PKGDIR/../.." && pwd)"
BUILDDIR="$TOPDIR/build"
REPODIR="$TOPDIR/repo"
VERSION="${1:-1.1.1}"
UPSTREAM_TAG="v$VERSION"

# Sandboxed Rust — inherits RUSTUP_HOME / CARGO_HOME from Makefile
export RUSTUP_HOME="${RUSTUP_HOME:-$BUILDDIR/rust/rustup}"
export CARGO_HOME="${CARGO_HOME:-$BUILDDIR/rust/cargo}"
PATH="$CARGO_HOME/bin:$RUSTUP_HOME/bin:$PATH"

STAGING="$BUILDDIR/scx-staging"
DEBNAME="scx_${VERSION}_amd64.deb"

rm -rf "$STAGING"
mkdir -p "$STAGING"

SOURCE_DIR="$BUILDDIR/scx-source"
rm -rf "$SOURCE_DIR"

echo "==> Cloning scx at $UPSTREAM_TAG..."
git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_URL" "$SOURCE_DIR"
rm -rf "$SOURCE_DIR/.git"

echo "==> Building scx..."
cd "$SOURCE_DIR"
cargo build --release --workspace \
  --exclude scxtop \
  --exclude xtask \
  --exclude scxcash \
  --exclude vmlinux_docify \
  --exclude scx_arena_selftests

echo "==> Building scxtop..."
# scxtop is excluded from workspace; build it separately
if [ -f "tools/scxtop/Cargo.toml" ]; then
  cargo build --release -p scxtop
elif ls tools/scxtop*/Cargo.toml 2>/dev/null; then
  cargo build --release -p scxtop
fi

echo "==> Installing to staging..."
SITEDIR="$STAGING/usr"

# Install scheduler binaries
SCHEDULERS="
  scx_beerland scx_bpfland scx_cake scx_chaos scx_cosmos
  scx_flash scx_flow scx_lavd scx_layered scx_mitosis
  scx_p2dq scx_pandemonium scx_rlfifo scx_rustland
  scx_rusty scx_tickless
"
for bin in $SCHEDULERS; do
  install -Dm755 "target/release/$bin" "$SITEDIR/bin/$bin"
done

# Install scxtop if it was built
if [ -f "target/release/scxtop" ]; then
  install -Dm755 "target/release/scxtop" "$SITEDIR/bin/scxtop"
fi


echo "==> Building .deb..."
DEB_DIR="$STAGING/DEBIAN"
mkdir -p "$DEB_DIR"

SIZE="$(du -sk "$STAGING" | cut -f1)"

cat > "$DEB_DIR/control" <<-CONTROL
Package: scx
Version: $VERSION
Architecture: amd64
Maintainer: $(grep -m1 'Maintainer:' "$PKGDIR/debian/control" | sed 's/Maintainer: *//')
Installed-Size: $SIZE
Depends: libbpf1 (>= 1.4.0), libc6, libelf1, libgcc-s1, libseccomp2, zlib1g
Section: misc
Priority: optional
Homepage: https://github.com/sched-ext/scx
Description: sched_ext schedulers and tools
 sched_ext is a Linux kernel feature which enables implementing kernel
 thread schedulers in BPF and dynamically loading them. This package
 contains various scheduler implementations and support utilities.
CONTROL

# Generate checksums
cd "$STAGING"
find usr -type f -exec md5sum {} \; > "$DEB_DIR/md5sums"

cd "$BUILDDIR"
dpkg-deb --build --root-owner-group scx-staging "$DEBNAME"

echo "==> Moving .deb to repo..."
mkdir -p "$REPODIR/pool/main/s/scx"
mv "$BUILDDIR/$DEBNAME" "$REPODIR/pool/main/s/scx/$DEBNAME"

rm -rf "$STAGING" "$SOURCE_DIR"

echo "==> Done: $DEBNAME"
