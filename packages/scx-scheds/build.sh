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
DEBNAME="scx-scheds_${VERSION}_amd64.deb"

# Verify the version tag exists upstream
echo "==> Verifying tag $UPSTREAM_TAG exists in scx repo..."
if ! git ls-remote --tags --refs "$UPSTREAM_URL" "$UPSTREAM_TAG" | grep -q .; then
  echo "ERROR: Tag $UPSTREAM_TAG not found in $UPSTREAM_URL" >&2
  exit 1
fi

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
if [ -f "tools/scxtop/Cargo.toml" ]; then
  cargo build --release -p scxtop
elif ls tools/scxtop*/Cargo.toml 2>/dev/null; then
  cargo build --release -p scxtop
fi

echo "==> Installing to staging..."
SITEDIR="$STAGING/usr"

# Dynamically discover all scheduler binaries
while IFS= read -r -d '' bin; do
  name=$(basename "$bin")
  install -Dm755 "$bin" "$SITEDIR/bin/$name"
done < <(find target/release -maxdepth 1 -type f -name 'scx_*' -print0)

# systemd service + config for running a scheduler directly at boot
install -Dm644 services/scx "$STAGING/etc/default/scx"
install -Dm644 services/scx.service "$STAGING/lib/systemd/system/scx.service"

echo "==> Building .deb..."
DEB_DIR="$STAGING/DEBIAN"
mkdir -p "$DEB_DIR"

SIZE="$(du -sk "$STAGING" | cut -f1)"

cat > "$DEB_DIR/control" <<-CONTROL
Package: scx-scheds
Version: $VERSION
Architecture: amd64
Maintainer: $(grep -m1 'Maintainer:' "$PKGDIR/debian/control" | sed 's/Maintainer: *//')
Installed-Size: $SIZE
Depends: libbpf1 (>= 1.4.0), libc6, libelf1, libgcc-s1, libseccomp2, zlib1g
Section: misc
Priority: optional
Homepage: https://github.com/sched-ext/scx
Description: sched_ext schedulers
 sched_ext is a Linux kernel feature which enables implementing kernel
 thread schedulers in BPF and dynamically loading them. This package
 contains various scheduler implementations.
CONTROL

cat > "$DEB_DIR/postinst" <<-'POSTINST'
#!/bin/sh
set -e

case "$1" in
  configure)
    if [ -z "$2" ]; then
      # fresh install
      systemctl enable --now scx.service || true
    fi
    ;;
  abort-upgrade|abort-remove|abort-deconfigure)
    ;;
esac
POSTINST
chmod 755 "$DEB_DIR/postinst"

cat > "$DEB_DIR/prerm" <<-'PRERM'
#!/bin/sh
set -e

case "$1" in
  remove|deconfigure)
    systemctl stop scx.service || true
    ;;
  upgrade)
    ;;
esac
PRERM
chmod 755 "$DEB_DIR/prerm"

cat > "$DEB_DIR/postrm" <<-'POSTRM'
#!/bin/sh
set -e

case "$1" in
  remove)
    systemctl disable scx.service || true
    systemctl daemon-reload || true
    ;;
  purge)
    systemctl disable scx.service || true
    systemctl daemon-reload || true
    ;;
  upgrade|failed-upgrade|abort-install|abort-upgrade|disappear)
    ;;
esac
POSTRM
chmod 755 "$DEB_DIR/postrm"

cd "$STAGING"
find usr -type f -exec md5sum {} \; > "$DEB_DIR/md5sums"

cd "$BUILDDIR"
dpkg-deb --build --root-owner-group scx-staging "$DEBNAME"

echo "==> Moving .deb to repo..."
mkdir -p "$REPODIR/pool/main/s/scx-scheds"
mv "$BUILDDIR/$DEBNAME" "$REPODIR/pool/main/s/scx-scheds/$DEBNAME"

rm -rf "$STAGING" "$SOURCE_DIR"

echo "==> Done: $DEBNAME"
