#!/bin/bash
# Build one .deb from an upstream sched-ext release tag.
#   build.sh scx-scheds|scx-tools VERSION [REVISION]
set -euo pipefail

[ $# -ge 2 ] || { echo "usage: $0 scx-scheds|scx-tools VERSION [REVISION]" >&2; exit 2; }
PKG=$1
VERSION=$2
DEBVERSION=$VERSION-${3:-1}

TOP=$(cd "$(dirname "$0")" && pwd)
MAINTAINER=${MAINTAINER:-"HM. Wassim <hmwassim95@gmail.com>"}
SRC=$TOP/build/src/$PKG
ROOT=$TOP/build/root/$PKG
OUT=$TOP/repo/pool/main/s/$PKG

# Rust toolchain lives in build/rust (bootstrapped by the Makefile).
export RUSTUP_HOME=${RUSTUP_HOME:-$TOP/build/rust/rustup}
export CARGO_HOME=${CARGO_HOME:-$TOP/build/rust/cargo}
export PATH=$CARGO_HOME/bin:$PATH

case $PKG in
scx-scheds)
    URL=https://github.com/sched-ext/scx
    DEPENDS=""
    HOMEPAGE=$URL
    DESCRIPTION="sched_ext schedulers
 sched_ext is a Linux kernel feature which enables implementing kernel
 thread schedulers in BPF and dynamically loading them. This package
 contains various scheduler implementations."
    ;;
scx-tools)
    URL=https://github.com/sched-ext/scx-loader
    DEPENDS="scx-scheds (>= $VERSION), polkitd, dbus"
    HOMEPAGE=$URL
    DESCRIPTION="sched_ext loader and control tools
 scx_loader is a DBus daemon that starts, stops and switches sched_ext
 schedulers. scxctl is its command-line client."
    ;;
*)
    echo "unknown package: $PKG" >&2
    exit 2
    ;;
esac

stage_scheds() {
    cargo build --release --workspace \
        --exclude xtask --exclude scxcash --exclude vmlinux_docify --exclude scx_arena_selftests

    # -executable skips cargo's scx_*.d dependency files
    find target/release -maxdepth 1 -type f -executable \( -name 'scx_*' -o -name scxtop \) \
        -exec install -Dm755 -t "$ROOT/usr/bin" {} +

    install -Dm644 services/scx.service "$ROOT/usr/lib/systemd/system/scx.service"
    install -Dm644 services/scx "$ROOT/etc/default/scx"
}

stage_tools() {
    cargo build --release

    install -Dm755 -t "$ROOT/usr/bin" target/release/scx_loader target/release/scxctl
    install -Dm644 services/scx_loader.service "$ROOT/usr/lib/systemd/system/scx_loader.service"
    install -Dm644 services/org.scx.Loader.service "$ROOT/usr/share/dbus-1/system-services/org.scx.Loader.service"
    install -Dm644 configs/org.scx.Loader.conf "$ROOT/usr/share/dbus-1/system.d/org.scx.Loader.conf"
    install -Dm644 configs/org.scx.Loader.xml "$ROOT/usr/share/dbus-1/interfaces/org.scx.Loader.xml"
    install -Dm644 configs/org.scx.Loader.policy "$ROOT/usr/share/polkit-1/actions/org.scx.Loader.policy"
    # Template only: postinst seeds /etc/scx_loader/config.toml, which scx-switcher rewrites.
    install -Dm644 configs/scx_loader.toml "$ROOT/usr/share/scx_loader/config.toml"
}

echo "==> $PKG $VERSION: fetching $URL at v$VERSION"
rm -rf "$SRC" "$ROOT"
git clone --quiet --depth 1 --branch "v$VERSION" "$URL" "$SRC"

echo "==> $PKG $VERSION: building"
cd "$SRC"
if [ "$PKG" = scx-scheds ]; then stage_scheds; else stage_tools; fi

echo "==> $PKG $VERSION: packaging"
mkdir -p "$ROOT/DEBIAN"
for script in postinst prerm postrm; do
    install -m755 "$TOP/packaging/$PKG/$script" "$ROOT/DEBIAN/$script"
done
if [ -d "$ROOT/etc" ]; then
    (cd "$ROOT" && find etc -type f -printf '/%p\n') > "$ROOT/DEBIAN/conffiles"
fi
(cd "$ROOT" && find usr -type f -exec md5sum {} +) > "$ROOT/DEBIAN/md5sums"

# Versioned library dependencies, computed from what the binaries link.
shlibs_dir=$(mktemp -d)
mkdir "$shlibs_dir/debian"
printf 'Source: %s\n\nPackage: %s\nArchitecture: any\n' "$PKG" "$PKG" > "$shlibs_dir/debian/control"
mapfile -t elfs < <(find "$ROOT/usr/bin" -type f)
shlibs=$(cd "$shlibs_dir" && dpkg-shlibdeps -O "${elfs[@]}" 2>/dev/null | sed -n 's/^shlibs:Depends=//p')
rm -rf "$shlibs_dir"
DEPENDS=$(printf '%s\n' "$shlibs" "$DEPENDS" | sed '/^$/d' | paste -sd, | sed 's/,/, /g')

cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $DEBVERSION
Architecture: amd64
Maintainer: $MAINTAINER
Installed-Size: $(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)
Depends: $DEPENDS
Section: misc
Priority: optional
Homepage: $HOMEPAGE
Description: $DESCRIPTION
EOF

mkdir -p "$OUT"
dpkg-deb --root-owner-group --build "$ROOT" "$OUT/${PKG}_${DEBVERSION}_amd64.deb"
rm -rf "$SRC" "$ROOT"
