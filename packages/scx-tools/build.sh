#!/bin/bash
set -euo pipefail

UPSTREAM_URL="https://github.com/sched-ext/scx-loader"
PKGDIR="$(cd "$(dirname "$0")" && pwd)"
TOPDIR="$(cd "$PKGDIR/../.." && pwd)"
BUILDDIR="$TOPDIR/build"
REPODIR="$TOPDIR/repo"
VERSION="${1:-1.1.2}"
UPSTREAM_TAG="v$VERSION"

# Sandboxed Rust — inherits RUSTUP_HOME / CARGO_HOME from Makefile
export RUSTUP_HOME="${RUSTUP_HOME:-$BUILDDIR/rust/rustup}"
export CARGO_HOME="${CARGO_HOME:-$BUILDDIR/rust/cargo}"
PATH="$CARGO_HOME/bin:$RUSTUP_HOME/bin:$PATH"

STAGING="$BUILDDIR/scx-tools-staging"
DEBNAME="scx-tools_${VERSION}_amd64.deb"

# Verify the version tag exists upstream
echo "==> Verifying tag $UPSTREAM_TAG exists in scx-loader repo..."
if ! git ls-remote --tags --refs "$UPSTREAM_URL" "$UPSTREAM_TAG" | grep -q .; then
  echo "ERROR: Tag $UPSTREAM_TAG not found in $UPSTREAM_URL" >&2
  exit 1
fi

rm -rf "$STAGING"
mkdir -p "$STAGING"

SOURCE_DIR="$BUILDDIR/scx-loader-source"
rm -rf "$SOURCE_DIR"

echo "==> Cloning scx-loader at $UPSTREAM_TAG..."
git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_URL" "$SOURCE_DIR"
rm -rf "$SOURCE_DIR/.git"

echo "==> Building scx-loader..."
cd "$SOURCE_DIR"
cargo build --release

echo "==> Installing to staging..."
SITEDIR="$STAGING/usr"

install -Dm755 target/release/scx_loader "$SITEDIR/bin/scx_loader"
install -Dm755 target/release/scxctl "$SITEDIR/bin/scxctl"

install -Dm644 services/scx_loader.service \
  "$SITEDIR/share/scx-tools/scx_loader.service"

install -Dm644 services/org.scx.Loader.service \
  "$SITEDIR/share/dbus-1/system-services/org.scx.Loader.service"
install -Dm644 configs/org.scx.Loader.conf \
  "$SITEDIR/share/dbus-1/system.d/org.scx.Loader.conf"
install -Dm644 configs/org.scx.Loader.xml \
  "$SITEDIR/share/dbus-1/interfaces/org.scx.Loader.xml"
install -Dm644 configs/org.scx.Loader.policy \
  "$SITEDIR/share/polkit-1/actions/org.scx.Loader.policy"
install -Dm644 configs/scx_loader.toml \
  "$SITEDIR/share/scx_loader/config.toml"

echo "==> Building .deb..."
DEB_DIR="$STAGING/DEBIAN"
mkdir -p "$DEB_DIR"

SIZE="$(du -sk "$STAGING" | cut -f1)"

cat > "$DEB_DIR/control" <<-CONTROL
Package: scx-tools
Version: $VERSION
Architecture: amd64
Maintainer: $(grep -m1 'Maintainer:' "$PKGDIR/debian/control" | sed 's/Maintainer: *//')
Installed-Size: $SIZE
Depends: scx-scheds (>= $VERSION), libc6, libgcc-s1, polkitd
Recommends: dbus
Section: misc
Priority: optional
Homepage: https://github.com/sched-ext/scx-loader
Description: sched_ext loader and control tools
 scx_loader is a system daemon and DBus-based loader for sched_ext
 schedulers. scxctl is the command-line client for managing schedulers
 at runtime.
CONTROL

# postinst: copy config, switch from direct service to loader
cat > "$DEB_DIR/postinst" <<-'POSTINST'
#!/bin/sh
set -e

case "$1" in
  configure)
    # Install symlink so systemd can discover the unit without dpkg
    # tracking /lib/systemd/system/ (avoids purge warning on shared dirs).
    mkdir -p /lib/systemd/system
    ln -sf /usr/share/scx-tools/scx_loader.service /lib/systemd/system/scx_loader.service

    systemctl daemon-reload || true

    # Transition from direct service to loader.
    systemctl disable scx.service 2>/dev/null || true
    systemctl stop scx.service 2>/dev/null || true
    systemctl enable scx_loader.service || true
    systemctl start scx_loader.service || true

    mkdir -p /etc/scx_loader
    if [ ! -f /etc/scx_loader/config.toml ]; then
      cp /usr/share/scx_loader/config.toml /etc/scx_loader/config.toml
    fi
    ;;
  abort-upgrade|abort-remove|abort-deconfigure)
    ;;
esac
POSTINST
chmod 755 "$DEB_DIR/postinst"

# prerm: stop + disable loader before removal
cat > "$DEB_DIR/prerm" <<-'PRERM'
#!/bin/sh
set -e

case "$1" in
  remove|deconfigure)
    systemctl disable --now scx_loader.service 2>/dev/null || true
    ;;
  upgrade)
    systemctl stop scx_loader.service 2>/dev/null || true
    ;;
esac
PRERM
chmod 755 "$DEB_DIR/prerm"

# postrm: daemon-reload, restore direct service
cat > "$DEB_DIR/postrm" <<-'POSTRM'
#!/bin/sh
set -e

case "$1" in
  remove)
    rm -f /lib/systemd/system/scx_loader.service
    systemctl daemon-reload || true
    if dpkg -s scx-scheds 2>/dev/null | grep -q '^Status: install ok installed'; then
      systemctl enable --now scx.service || true
    fi
    ;;
  purge)
    rm -f /lib/systemd/system/scx_loader.service
    systemctl daemon-reload || true
    rm -f /etc/scx_loader/config.toml
    rmdir /etc/scx_loader 2>/dev/null || true
    ;;
  upgrade|failed-upgrade|abort-install|abort-upgrade|disappear)
    ;;
esac
POSTRM
chmod 755 "$DEB_DIR/postrm"

cd "$STAGING"
find usr -type f -exec md5sum {} \; > "$DEB_DIR/md5sums"

cd "$BUILDDIR"
dpkg-deb --build --root-owner-group scx-tools-staging "$DEBNAME"

echo "==> Moving .deb to repo..."
mkdir -p "$REPODIR/pool/main/s/scx-tools"
mv "$BUILDDIR/$DEBNAME" "$REPODIR/pool/main/s/scx-tools/$DEBNAME"

rm -rf "$STAGING" "$SOURCE_DIR"

echo "==> Done: $DEBNAME"
